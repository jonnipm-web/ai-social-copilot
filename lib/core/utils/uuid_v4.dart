import 'dart:math';

/// IVE-COMMERCIAL-QUOTA-HARDENING-13 (mission Section 05: "Recommended:
/// UUID v4 / secure equivalent") — generates a random RFC 4122 version 4
/// UUID, e.g. "3fa85f64-5717-4562-b3fc-2c963f66afa6". Deliberately
/// separate from diagnostic_logger_service.dart's
/// newDiagnosticCorrelationId(), which generates a similar-looking but
/// NOT-a-real-UUID base36 shape — the AI-quota idempotency key is stored
/// server-side as a genuine Postgres `uuid` column (migration
/// 20260918000000) and must actually parse as one.
///
/// No external `uuid` package dependency: this is a small, self-contained
/// utility, matching the codebase's existing pattern of writing its own
/// ID generators rather than pulling in a package for it.
final Random _uuidRng = Random.secure();

String newUuidV4() {
  final bytes = List<int>.generate(16, (_) => _uuidRng.nextInt(256));
  // Version 4: top nibble of byte 6 is 0100.
  bytes[6] = (bytes[6] & 0x0F) | 0x40;
  // Variant (RFC 4122): top two bits of byte 8 are 10.
  bytes[8] = (bytes[8] & 0x3F) | 0x80;
  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
