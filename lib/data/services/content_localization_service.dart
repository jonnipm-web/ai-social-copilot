import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/language_utils.dart';

/// R16 — presentation localization of PERSISTED content.
///
/// Historical AI output (and a few original user fields such as
/// `projects.description`) is stored in whatever language it was produced in.
/// When the presentation language differs, rows are passed through the
/// `localize-content` Edge Function, which returns a cached translated
/// PRESENTATION of the allow-listed columns. The original row in the database
/// is never modified (R16 §8), no analysis quota is consumed (R16 §21) and
/// each (row, language) is translated at most once server-side.
///
/// A [RowLocalizer] takes raw rows (as returned by Supabase) and returns rows
/// whose presentation columns are replaced by their localized version. It
/// NEVER throws and NEVER drops rows: on any failure the originals are used.
typedef RowLocalizer = Future<List<Map<String, dynamic>>> Function(
  String table,
  List<Map<String, dynamic>> rows,
);

/// Marker added to a localized row: the detected source language
/// ('pt-BR', 'en-US', ...). Models may read it to show a "translated" notice.
const String kLocalizedFromKey = 'r16_localized_from';

/// Prefix under which the original value of a localized column is kept.
const String kOriginalPrefix = 'r16_original_';

/// Suffix used for tables whose ORIGINAL user text must stay editable
/// (projects): the translation goes to `<column>_localized` instead of
/// replacing the column, so edit forms keep the original.
const Set<String> kSideBySideTables = {'projects'};

/// Identity localizer — used when the user chose to see original content or
/// when no presentation language applies (tests, services built manually).
Future<List<Map<String, dynamic>>> identityLocalizer(
  String table,
  List<Map<String, dynamic>> rows,
) async =>
    rows;

class ContentLocalizationService {
  ContentLocalizationService({SupabaseClient? client}) : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  SupabaseClient get _client => _clientOverride ?? Supabase.instance.client;

  static const int _maxIdsPerCall = 25;

  /// Session memo: `table|id|language|updated_at` -> localized payload.
  final Map<String, _Localized> _memo = {};

  /// Returns a [RowLocalizer] bound to [language] ('pt-BR' | 'en-US').
  RowLocalizer localizerFor(String language) =>
      (table, rows) => localizeRows(table, rows, language);

  /// In-flight requests keyed like [_memo], so concurrent providers asking
  /// for the same rows share ONE server call (no duplicate translations).
  final Map<String, Future<void>> _inflight = {};

  Future<List<Map<String, dynamic>>> localizeRows(
    String table,
    List<Map<String, dynamic>> rows,
    String language,
  ) async {
    if (rows.isEmpty) return rows;
    try {
      final byKey = <String, Map<String, dynamic>>{};
      for (final r in rows) {
        if (r['id'] == null) continue;
        byKey[_key(table, language, r)] = r;
      }
      final waits = <Future<void>>[];
      final missing = <String, Map<String, dynamic>>{};
      byKey.forEach((k, r) {
        if (_memo.containsKey(k)) return;
        final pending = _inflight[k];
        if (pending != null) {
          waits.add(pending);
        } else {
          missing[k] = r;
        }
      });

      final keys = missing.keys.toList();
      for (var i = 0; i < keys.length; i += _maxIdsPerCall) {
        final chunkKeys = keys.sublist(i, (i + _maxIdsPerCall).clamp(0, keys.length));
        final call = _fetchChunk(table, language, {for (final k in chunkKeys) k: missing[k]!});
        for (final k in chunkKeys) {
          _inflight[k] = call;
        }
        waits.add(call.whenComplete(() {
          for (final k in chunkKeys) {
            _inflight.remove(k);
          }
        }));
      }
      await Future.wait(waits);

      return rows
          .map((r) => r['id'] == null ? r : mergeLocalized(table, r, _memo[_key(table, language, r)], language))
          .toList();
    } catch (e) {
      debugPrint('R16 localize-content failed for $table: $e');
      return rows; // never block rendering; originals are shown
    }
  }

  Future<void> _fetchChunk(String table, String language, Map<String, Map<String, dynamic>> chunk) async {
    final ids = chunk.values.map((r) => r['id'].toString()).toSet().toList();
    Map? items;
    try {
      final response = await _client.functions.invoke(
        'localize-content',
        body: {'table': table, 'ids': ids, 'language': language},
      );
      final data = response.data;
      items = data is Map && data['items'] is Map ? data['items'] as Map : null;
    } catch (e) {
      // Not memoised: a transient failure is retried on the next read.
      debugPrint('R16 localize-content call failed for $table: $e');
      return;
    }
    chunk.forEach((k, row) {
      final item = items?[row['id'].toString()];
      _memo[k] = item is Map
          ? _Localized(
              sourceLanguage: item['source_language']?.toString(),
              payload: Map<String, dynamic>.from(item['payload'] as Map? ?? const {}),
            )
          : const _Localized(sourceLanguage: null, payload: {});
    });
  }

  /// Memo key includes a fingerprint of the row content, so a re-run that
  /// keeps the same id (upserted analyses) or an edit never shows a stale
  /// translation of the previous content.
  static String _key(String table, String language, Map<String, dynamic> row) =>
      '$table|${row['id']}|$language|${_fingerprint(row)}';

  static int _fingerprint(Map<String, dynamic> row) {
    final keys = row.keys.where((k) => !k.startsWith('r16_')).toList()..sort();
    return Object.hashAll(keys.map((k) => '$k=${row[k]}'));
  }

}

class _Localized {
  const _Localized({required this.sourceLanguage, required this.payload});
  final String? sourceLanguage;
  final Map<String, dynamic> payload;
}

/// Pure merge (unit-tested): overlays the localized payload onto a COPY of
/// the row. Rows already in the presentation language are returned as-is.
@visibleForTesting
Map<String, dynamic> mergeLocalized(
  String table,
  Map<String, dynamic> row,
  Object? localized,
  String language,
) {
  if (localized is! _Localized || localized.payload.isEmpty) return row;
  final src = localized.sourceLanguage ?? '';
  final sameLanguage = src.length >= 2 && src.substring(0, 2).toLowerCase() == language.substring(0, 2).toLowerCase();
  if (sameLanguage) return row;
  final out = Map<String, dynamic>.from(row);
  localized.payload.forEach((column, value) {
    if (kSideBySideTables.contains(table)) {
      out['${column}_localized'] = value;
    } else {
      // Keep the ORIGINAL value next to the presentation value: logic that
      // must not depend on the presentation language (e.g. niche overlap
      // between projects, R16 §20) reads `r16_original_<column>`.
      out['$kOriginalPrefix$column'] = row[column];
      out[column] = value;
    }
  });
  // Unknown detected language still marks the row as translated, so the
  // "translated" notice is always shown (R16 §9).
  out[kLocalizedFromKey] = src.isEmpty ? 'und' : src;
  return out;
}

/// Test hook to build a localized entry without exposing the private type.
@visibleForTesting
Object debugLocalizedEntry(String? sourceLanguage, Map<String, dynamic> payload) =>
    _Localized(sourceLanguage: sourceLanguage, payload: payload);

final contentLocalizationServiceProvider =
    Provider<ContentLocalizationService>((_) => ContentLocalizationService());

/// When true the app shows persisted content in its ORIGINAL language
/// (explicit user choice via the "View original" control, R16 §9).
final showOriginalContentProvider = StateProvider<bool>((_) => false);

/// The localizer every read path uses. Watching it makes providers refetch on
/// a PT↔EN switch or on the original/translated toggle — no stale language.
final rowLocalizerProvider = Provider<RowLocalizer>((ref) {
  if (ref.watch(showOriginalContentProvider)) return identityLocalizer;
  final language = ref.watch(outputLanguageCodeProvider);
  return ref.watch(contentLocalizationServiceProvider).localizerFor(language);
});
