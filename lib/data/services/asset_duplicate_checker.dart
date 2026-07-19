import '../models/asset.dart';
import '../models/asset_import_proposal.dart';
import '../models/parsed_content.dart';

/// Resultado do duplicate check com decisão pendente do usuário.
class DuplicateCheckResult {
  const DuplicateCheckResult({
    required this.candidates,
    required this.recommendation,
  });

  final List<DuplicateCandidate> candidates;

  /// Recomendação automática (não vinculante — usuário decide).
  final DuplicateDecision recommendation;

  bool get hasCandidates    => candidates.isNotEmpty;
  bool get isHighConfidence => candidates.any((c) => c.confidence >= 0.9);
}

/// Detecta possíveis duplicatas entre conteúdo a importar e assets existentes.
///
/// Não bloqueia automaticamente — apresenta candidatos ao usuário para decisão.
/// Critérios verificados:
///   - fingerprint (hash SHA-256 do conteúdo)
///   - URL normalizada
///   - nome similar
///   - identificadores específicos (ISBN, DOI, etc.)
class AssetDuplicateChecker {
  const AssetDuplicateChecker();

  DuplicateCheckResult check({
    required ParsedContent content,
    required List<Asset>   existingAssets,
  }) {
    if (existingAssets.isEmpty) {
      return const DuplicateCheckResult(
        candidates:     [],
        recommendation: DuplicateDecision.createNew,
      );
    }

    final candidates = <DuplicateCandidate>[];

    for (final asset in existingAssets) {
      final candidate = _checkAsset(content, asset);
      if (candidate != null) candidates.add(candidate);
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));

    return DuplicateCheckResult(
      candidates:     candidates,
      recommendation: _recommend(candidates),
    );
  }

  DuplicateCandidate? _checkAsset(ParsedContent content, Asset asset) {
    double maxConfidence = 0.0;
    String matchReason   = '';

    // 1. Fingerprint (SHA-256 exato)
    if (content.hasFingerprint) {
      final storedFp = asset.metadata['fingerprint'] as String?;
      if (storedFp != null && storedFp == content.fingerprint) {
        return DuplicateCandidate(
          existingId:    asset.id,
          existingTitle: asset.name,
          existingType:  asset.type.dbValue,
          matchReason:   'Conteúdo idêntico (fingerprint SHA-256)',
          confidence:    1.0,
        );
      }
    }

    // 2. URL normalizada
    final contentUrl = _extractUrlFromContent(content);
    if (contentUrl != null) {
      final assetUrl = (asset.metadata['source_url'] ?? asset.metadata['url']) as String?;
      if (assetUrl != null) {
        final conf = _urlSimilarity(contentUrl, assetUrl);
        if (conf > maxConfidence) {
          maxConfidence = conf;
          matchReason   = 'URL correspondente';
        }
      }
    }

    // 3. Nome similar
    final contentTitle = content.title ?? '';
    if (contentTitle.isNotEmpty && asset.name.isNotEmpty) {
      final conf = _nameSimilarity(contentTitle, asset.name);
      if (conf > maxConfidence) {
        maxConfidence = conf;
        matchReason   = 'Nome similar';
      }
    }

    // 4. Identificadores específicos (ISBN, DOI)
    final contentIds = _extractIdentifiersFromContent(content);
    final assetIds   = _extractIdentifiersFromAsset(asset);
    for (final id in contentIds) {
      if (assetIds.contains(id)) {
        maxConfidence = 1.0;
        matchReason   = 'Identificador único correspondente ($id)';
        break;
      }
    }

    if (maxConfidence >= 0.6) {
      return DuplicateCandidate(
        existingId:    asset.id,
        existingTitle: asset.name,
        existingType:  asset.type.dbValue,
        matchReason:   matchReason,
        confidence:    maxConfidence,
      );
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _extractUrlFromContent(ParsedContent content) {
    final url = content.structuredData?['url'] as String?;
    if (url != null) return _normalizeUrl(url);
    final raw = content.rawText.trim();
    if (raw.startsWith('http')) return _normalizeUrl(raw);
    return null;
  }

  String _normalizeUrl(String url) =>
      url.toLowerCase().replaceAll(RegExp(r'/$'), '').replaceAll('www.', '');

  double _urlSimilarity(String a, String b) {
    if (_normalizeUrl(a) == _normalizeUrl(b)) return 0.95;
    final dA = Uri.tryParse(a)?.host ?? '';
    final dB = Uri.tryParse(b)?.host ?? '';
    if (dA.isNotEmpty && dA == dB) return 0.7;
    return 0.0;
  }

  double _nameSimilarity(String a, String b) {
    final na = _normalizeName(a);
    final nb = _normalizeName(b);
    if (na == nb)              return 0.9;
    if (na.contains(nb) || nb.contains(na)) return 0.75;

    final wa = na.split(RegExp(r'\s+'));
    final wb = nb.split(RegExp(r'\s+'));
    if (wa.isEmpty || wb.isEmpty) return 0.0;

    final intersection = wa.where((w) => wb.contains(w)).length;
    final union        = ({...wa, ...wb}).length;
    return union == 0 ? 0.0 : intersection / union;
  }

  String _normalizeName(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  List<String> _extractIdentifiersFromContent(ParsedContent content) {
    final ids  = <String>[];
    final text = '${content.rawText} ${content.title ?? ''}';

    for (final m in RegExp(r'\b(?:\d{9}[\dXx]|\d{13})\b').allMatches(text)) {
      ids.add('isbn:${m.group(0)?.replaceAll(RegExp(r'[^0-9Xx]'), '')}');
    }
    for (final m in RegExp(r'\b10\.\d{4,}/\S+').allMatches(text)) {
      ids.add('doi:${m.group(0)}');
    }
    return ids;
  }

  List<String> _extractIdentifiersFromAsset(Asset asset) {
    final ids  = <String>[];
    final meta = asset.metadata;

    final isbn = meta['isbn'] as String?;
    if (isbn != null) ids.add('isbn:${isbn.replaceAll(RegExp(r'[^0-9Xx]'), '')}');

    final doi = meta['doi'] as String?;
    if (doi != null) ids.add('doi:$doi');

    return ids;
  }

  DuplicateDecision _recommend(List<DuplicateCandidate> candidates) {
    if (candidates.isEmpty)                     return DuplicateDecision.createNew;
    if (candidates.first.confidence >= 0.95)    return DuplicateDecision.useExisting;
    if (candidates.first.confidence >= 0.7)     return DuplicateDecision.updateExisting;
    return DuplicateDecision.createNew;
  }
}
