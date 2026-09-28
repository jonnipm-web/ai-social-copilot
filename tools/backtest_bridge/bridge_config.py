"""INSIGHTVALUES-STRATEGY-INTELLIGENCE-MACRO-07 §5-7 -- bridge configuration.

Macro-06 required an operator to export TWO environment variables
(STRATEGY_FIDELITY_PYTHONPATH, WIN1_CSV_PATH) by hand before every run of
backtest_service.py. That was already never exposed to a normal product
user (the TS/Flutter/HTTP paths only ever send dataset_id/engine_id, never
a filesystem path -- see dataset_registry.ts/engine_registry.ts), but it
was still real per-run operator plumbing for whoever runs this Lab-only
bridge.

This module collapses that into ONE versioned local config file, read
once at process start:
    tools/backtest_bridge/bridge_config.json   (gitignored -- machine-
                                                 specific real paths)
A checked-in bridge_config.example.json documents the two keys with
placeholder values.

This does NOT eliminate the underlying constraint that the real WIN1!
dataset must physically exist somewhere on whichever machine operates
this bridge (it is not distributable -- Macro-05 §17/§39). What it
removes is the requirement that a human re-type two env vars every time
the service starts, and it turns a missing/invalid config into one
clean, structured "unavailable" state (describe_availability()) instead
of a failure only discovered after a request times out.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path

DEFAULT_CONFIG_PATH = Path(__file__).parent / "bridge_config.json"


@dataclass(frozen=True)
class BridgeConfig:
    strategy_fidelity_pythonpath: str | None
    win1_csv_path: str | None
    config_path: Path
    load_error: str | None


def _config_path() -> Path:
    override = os.environ.get("BACKTEST_BRIDGE_CONFIG")
    return Path(override) if override else DEFAULT_CONFIG_PATH


def load_bridge_config() -> BridgeConfig:
    """Reads the local bridge config file once. Never raises -- a missing
    or malformed file becomes a BridgeConfig with load_error set, so the
    service can still start and report a clean unavailable state per
    engine instead of crashing at import time."""
    path = _config_path()
    if not path.is_file():
        return BridgeConfig(None, None, path, f"config file not found: {path}")
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return BridgeConfig(None, None, path, f"config file unreadable: {type(exc).__name__}")
    if not isinstance(raw, dict):
        return BridgeConfig(None, None, path, "config file must contain a JSON object")
    pythonpath = raw.get("strategy_fidelity_pythonpath")
    csv_path = raw.get("win1_csv_path")
    if pythonpath is not None and not isinstance(pythonpath, str):
        return BridgeConfig(None, None, path, "strategy_fidelity_pythonpath must be a string")
    if csv_path is not None and not isinstance(csv_path, str):
        return BridgeConfig(None, None, path, "win1_csv_path must be a string")
    return BridgeConfig(pythonpath, csv_path, path, None)


def describe_v10_availability(config: BridgeConfig) -> tuple[bool, str | None]:
    """Returns (available, reason_if_not) for PAULO_TREND_FIBONACCI_V10,
    without importing the (possibly unavailable) quant package -- this is
    a fast, dependency-free health check."""
    if config.load_error:
        return False, config.load_error
    if not config.strategy_fidelity_pythonpath:
        return False, "strategy_fidelity_pythonpath not configured"
    if not Path(config.strategy_fidelity_pythonpath).is_dir():
        return False, "strategy_fidelity_pythonpath does not point at a real directory"
    if not config.win1_csv_path:
        return False, "win1_csv_path not configured"
    if not Path(config.win1_csv_path).is_file():
        return False, "win1_csv_path does not point at a real file"
    return True, None
