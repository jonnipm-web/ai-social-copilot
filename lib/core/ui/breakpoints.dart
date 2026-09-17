// COMMERCIAL-EXPERIENCE-CLOSURE-16 — single source of truth for the
// desktop/tablet thresholds that were previously duplicated ad hoc (e.g.
// IveOverlay._isDesktop, executive_dashboard_screen.dart's private _Bp).
// Values match the existing convention already used across the app
// (600/1024/1440), not new numbers invented for this mission.
abstract final class Breakpoints {
  static bool isTablet(double width) => width >= 600;
  static bool isDesktop(double width) => width >= 1024;
  static bool isWide(double width) => width >= 1440;
}
