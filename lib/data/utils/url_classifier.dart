enum UrlType {
  googleDoc,
  googleDriveFile,
  pdf,
  docx,
  youtube,
  webPage,
  unknown,
}

class UrlClassifier {
  static UrlType classify(String url) {
    if (url.trim().isEmpty) return UrlType.unknown;
    final u = url.toLowerCase().trim();
    if (u.contains('docs.google.com/document/d/')) return UrlType.googleDoc;
    if (u.contains('drive.google.com/file/d/')) return UrlType.googleDriveFile;
    if (u.endsWith('.pdf') || u.contains('.pdf?') || u.contains('.pdf#')) return UrlType.pdf;
    if (u.endsWith('.docx') || u.contains('.docx?')) return UrlType.docx;
    if (u.contains('youtube.com/watch') || u.contains('youtu.be/')) return UrlType.youtube;
    if (u.startsWith('http')) return UrlType.webPage;
    return UrlType.unknown;
  }

  static String label(UrlType type) {
    switch (type) {
      case UrlType.googleDoc:      return 'Google Doc';
      case UrlType.googleDriveFile: return 'Google Drive (arquivo)';
      case UrlType.pdf:            return 'PDF';
      case UrlType.docx:           return 'Word (DOCX)';
      case UrlType.youtube:        return 'YouTube';
      case UrlType.webPage:        return 'Página Web';
      case UrlType.unknown:        return 'URL';
    }
  }

  static bool isSupported(UrlType type) =>
      type != UrlType.youtube && type != UrlType.unknown;

  static String? hint(UrlType type) {
    switch (type) {
      case UrlType.googleDoc:
        return 'Google Doc detectado. Certifique-se de que está compartilhado como "Qualquer pessoa com o link".';
      case UrlType.googleDriveFile:
        return 'Link Drive detectado. Compartilhe como "Qualquer pessoa com o link". Para melhor resultado, converta para Google Doc.';
      case UrlType.pdf:
        return 'PDF detectado. O texto será extraído automaticamente.';
      case UrlType.docx:
        return 'Word (DOCX) detectado. O texto será extraído automaticamente.';
      case UrlType.youtube:
        return 'YouTube não é suportado. Cole a transcrição do vídeo na opção "Texto Manual".';
      case UrlType.webPage:
        return 'Página Web detectada. O conteúdo textual será extraído.';
      case UrlType.unknown:
        return null;
    }
  }
}
