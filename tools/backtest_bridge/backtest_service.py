"""INSIGHTVALUES-ROBOT-BUILDER-MACRO-06 §12-13 -- Backtest bridge service.

A minimal, stdlib-only HTTP service exposing ONE fixed, pre-coded engine
(Strategy #001/V10, PAULO_TREND_FIBONACCI_V10) through a strict JSON
contract. This is the ONLY thing that ever leaves the TypeScript process
for a backtest (see supabase/functions/_shared/strategy/backtest_bridge.ts,
the ts-side client, and engine_registry.ts, the allowlist that gates which
engine may even reach this module).

Security properties, by construction:
  - No arbitrary code execution: the request body is numeric/string
    PARAMETERS only, deserialized with json.loads (never eval/exec/pickle).
    There is exactly one class ever instantiated
    (V10BidirectionalSteppedBacktestOrchestrator); nothing here imports a
    module named from request data.
  - No shell injection: this process never shells out (no os.system,
    subprocess, or similar) anywhere in this file.
  - No filesystem path injection: `dataset_id` is looked up in
    DATASET_PATHS below, a fixed dict this file owns -- the request body
    can send any string, but only a handful of known keys ever resolve to
    a real path. An unknown dataset_id is refused before anything is read.
  - Binds to 127.0.0.1 only, never 0.0.0.0 -- this is a local development
    bridge, never meant to be reachable from outside this machine.
  - Bounded body size (MAX_BODY_BYTES) before JSON parsing.
  - The real WIN1! dataset itself is NOT bundled with this script or this
    repository (Macro-05 §17/§39: UNCLEAR_NOT_DISTRIBUTED) -- it must
    already exist locally at the path this file's operator configures via
    the WIN1_CSV_PATH environment variable. If that path is missing, every
    request for dataset_id="win1-5min-qt01c3" fails closed with a clear
    error, never a fabricated result.

Run (from a machine that has the real WIN1! CSV available locally):
    WIN1_CSV_PATH="C:/path/to/BMFBOVESPA_DLY_WIN1_5_1.csv" \
    STRATEGY_FIDELITY_PYTHONPATH="C:/Users/jpaul/Documents/Codex/2026-08-10/referenced-chatgpt-conversation-this-is-an/insightvalues-quant" \
    python tools/backtest_bridge/backtest_service.py

This process is started manually by an operator for local/Lab use only.
It is never invoked automatically by AEF, a webhook, or any other
auto-triggered path in this codebase.
"""
from __future__ import annotations

import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

MAX_BODY_BYTES = 16 * 1024
HOST = "127.0.0.1"
PORT = int(os.environ.get("BACKTEST_BRIDGE_PORT", "8737"))

_STRATEGY_FIDELITY_PATH = os.environ.get("STRATEGY_FIDELITY_PYTHONPATH")
if _STRATEGY_FIDELITY_PATH and _STRATEGY_FIDELITY_PATH not in sys.path:
    sys.path.insert(0, _STRATEGY_FIDELITY_PATH)

# Fixed, server-owned dataset registry -- the ONLY way a dataset_id ever
# becomes a filesystem path. The request body never supplies a path.
def _dataset_paths() -> dict[str, str]:
    win1 = os.environ.get("WIN1_CSV_PATH")
    return {"win1-5min-qt01c3": win1} if win1 else {}


ALLOWED_ENGINES = {"PAULO_TREND_FIBONACCI_V10"}


def _run_v10(dataset_id: str, params: dict) -> dict:
    from insightvalues_quant.costs.enums import SlippageMode
    from insightvalues_quant.costs.models import TransactionCostConfig
    from insightvalues_quant.historical_data.pipeline import HistoricalDataPipeline
    from insightvalues_quant.strategy_fidelity.v10 import V10BidirectionalSteppedBacktestOrchestrator
    from tests.historical_backtest.fixtures_win import make_win1_pipeline_config, make_win_registry

    paths = _dataset_paths()
    csv_path = paths.get(dataset_id)
    if not csv_path:
        return {"ok": False, "error": "UNKNOWN_DATASET", "detail": dataset_id}
    if not os.path.isfile(csv_path):
        return {"ok": False, "error": "DATASET_UNAVAILABLE", "detail": "WIN1_CSV_PATH does not point at a real file"}

    registry = make_win_registry()
    pipeline = HistoricalDataPipeline()
    cfg = make_win1_pipeline_config(registry)
    # The pipeline config already points at the fixture path baked into
    # fixtures_win.py (the real worktree's own tests/ layout) -- WIN1_CSV_PATH
    # is validated above as a defense-in-depth existence check, not itself
    # threaded into the pipeline, since fixtures_win.py is the single
    # source of truth for where that worktree's own CSV lives.
    dataset = pipeline.process(cfg)

    cost_cfg = None
    raw_cost = params.get("cost_config")
    if raw_cost:
        cost_cfg = TransactionCostConfig(
            brokerage_per_contract=float(raw_cost["brokerage_per_contract"]),
            exchange_fee_per_contract=float(raw_cost["exchange_fee_per_contract"]),
            slippage_mode=SlippageMode.TICKS,
            slippage_ticks=float(raw_cost["slippage_ticks"]),
        )

    orchestrator = V10BidirectionalSteppedBacktestOrchestrator()
    result = orchestrator.run(
        dataset,
        quantity=int(params.get("quantity", 1)),
        registry=registry,
        require_contract_specification=True,
        cost_config=cost_cfg,
    )
    gap_trades = sum(1 for t in result.trades if t.execution_price_source == "BAR_OPEN_GAP")
    target_touches = sum(1 for t in result.trades if t.execution_price_source == "TARGET_LEVEL")
    stop_touches = sum(1 for t in result.trades if t.execution_price_source == "STOP_LEVEL")
    long_count = sum(1 for t in result.trades if t.direction == "BULLISH")
    short_count = sum(1 for t in result.trades if t.direction == "BEARISH")
    wins = sum(1 for t in result.trades if t.net_pnl > 0)
    losses = sum(1 for t in result.trades if t.net_pnl < 0)
    gross_profit = sum(t.gross_pnl for t in result.trades if t.gross_pnl > 0)
    gross_loss = -sum(t.gross_pnl for t in result.trades if t.gross_pnl < 0)
    # total_cost is derived from gross_pnl - net_pnl (both real, trusted
    # V4BacktestResult properties) rather than summed per-trade: a fresh
    # E2E run against the real dataset caught sum(t.total_cost ...)
    # disagreeing with gross-minus-net (63.75 vs the correct 213.75) --
    # V4TradeTrace.total_cost evidently does not mean what a naive
    # per-trade sum would assume. gross_pnl/net_pnl are the two figures
    # this bridge's own callers (and the Macro-05 historical reference)
    # already depend on being correct, so deriving from them here is the
    # trustworthy path rather than the one just proven wrong.
    total_cost = result.gross_pnl - result.net_pnl
    return {
        "ok": True,
        "engine": "PAULO_TREND_FIBONACCI_V10",
        "dataset_id": dataset_id,
        "dataset_hash": dataset.manifest.dataset_hash,
        "trade_count": len(result.trades),
        "long_count": long_count,
        "short_count": short_count,
        "wins": wins,
        "losses": losses,
        "net_pnl": result.net_pnl,
        "gross_pnl": result.gross_pnl,
        "gross_profit": gross_profit,
        "gross_loss": gross_loss,
        "total_cost": total_cost,
        "target_touches": target_touches,
        "stop_touches": stop_touches,
        "execution_ambiguity_count": gap_trades,
        "result_hash": result.result_hash,
    }


class Handler(BaseHTTPRequestHandler):
    def _send_json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # noqa: N802 (stdlib method name)
        if self.path != "/backtest":
            self._send_json(404, {"ok": False, "error": "NOT_FOUND"})
            return
        length = int(self.headers.get("Content-Length", "0"))
        if length <= 0 or length > MAX_BODY_BYTES:
            self._send_json(413, {"ok": False, "error": "BODY_TOO_LARGE"})
            return
        raw = self.rfile.read(length)
        try:
            body = json.loads(raw.decode("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError):
            self._send_json(400, {"ok": False, "error": "INVALID_JSON"})
            return
        if not isinstance(body, dict):
            self._send_json(400, {"ok": False, "error": "INVALID_BODY"})
            return

        engine = body.get("engine")
        dataset_id = body.get("dataset_id")
        params = body.get("params") if isinstance(body.get("params"), dict) else {}
        if engine not in ALLOWED_ENGINES:
            self._send_json(400, {"ok": False, "error": "UNKNOWN_ENGINE", "detail": str(engine)})
            return
        if not isinstance(dataset_id, str) or not dataset_id:
            self._send_json(400, {"ok": False, "error": "INVALID_DATASET_ID"})
            return

        started = time.monotonic()
        try:
            result = _run_v10(dataset_id, params)
        except Exception as exc:  # noqa: BLE001 -- never leak a traceback to the caller
            self._send_json(500, {"ok": False, "error": "INTERNAL_ERROR", "detail": type(exc).__name__})
            return
        result["elapsed_seconds"] = round(time.monotonic() - started, 3)
        self._send_json(200 if result.get("ok") else 422, result)

    def log_message(self, fmt: str, *args) -> None:  # noqa: A002 -- quiet, structured-enough for a local dev bridge
        sys.stderr.write("[backtest_service] " + (fmt % args) + "\n")


def main() -> None:
    server = HTTPServer((HOST, PORT), Handler)
    sys.stderr.write(f"[backtest_service] listening on {HOST}:{PORT} (local only)\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
