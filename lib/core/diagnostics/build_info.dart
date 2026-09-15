/// IVE-COMMERCIAL-STABILITY-09O — canonical build identity.
///
/// Baked in at compile time via `--dart-define=BUILD_SHA=<git sha>` (see
/// .github/workflows/deploy-web.yml, which passes `${{ github.sha }}` — the
/// exact commit CI is building and about to publish). Never a manually
/// maintained constant: there is nothing here for a human to update or let
/// drift, and a build produced any other way (a local `flutter build` with
/// no `--dart-define`) visibly falls back to `'unknown'` rather than
/// silently claiming an incorrect commit.
///
/// This is the one join key a future production diagnostic event needs to
/// find its exact matching private source-map artifact (see
/// tool/stability09o/), since diagnostic_sessions.build_sha (see
/// diagnostic_logger_service.dart's startSession) is populated from this
/// constant.
const String kBuildSha = String.fromEnvironment('BUILD_SHA', defaultValue: 'unknown');
