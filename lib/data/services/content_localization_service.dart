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

  Future<List<Map<String, dynamic>>> localizeRows(
    String table,
    List<Map<String, dynamic>> rows,
    String language,
  ) async {
    if (rows.isEmpty) return rows;
    try {
      final missing = <String>[];
      for (final r in rows) {
        final id = r['id']?.toString();
        if (id == null) continue;
        if (!_memo.containsKey(_key(table, id, language, r))) missing.add(id);
      }
      for (var i = 0; i < missing.length; i += _maxIdsPerCall) {
        final chunk = missing.sublist(i, (i + _maxIdsPerCall).clamp(0, missing.length));
        final response = await _client.functions.invoke(
          'localize-content',
          body: {'table': table, 'ids': chunk, 'language': language},
        );
        final data = response.data;
        final items = (data is Map ? data['items'] : null);
        for (final id in chunk) {
          final item = items is Map ? items[id] : null;
          final row = rows.firstWhere((r) => r['id']?.toString() == id);
          _memo[_key(table, id, language, row)] = item is Map
              ? _Localized(
                  sourceLanguage: item['source_language']?.toString(),
                  payload: Map<String, dynamic>.from(item['payload'] as Map? ?? const {}),
                )
              : const _Localized(sourceLanguage: null, payload: {});
        }
      }
      return rows
          .map((r) => mergeLocalized(table, r, _memo[_key(table, r['id']?.toString() ?? '', language, r)], language))
          .toList();
    } catch (e) {
      debugPrint('R16 localize-content failed for $table: $e');
      return rows; // never block rendering; originals are shown
    }
  }

  /// `updated_at` (when the table has it) invalidates the memo after an edit.
  static String _key(String table, String id, String language, Map<String, dynamic> row) =>
      '$table|$id|$language|${row['updated_at'] ?? ''}';
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
      out[column] = value;
    }
  });
  out[kLocalizedFromKey] = src.isEmpty ? null : src;
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
