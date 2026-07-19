/// Fonte de origem de um item a ser ingerido no Asset Ingestion Hub.
enum IngestionSource {
  manual,
  library,
  fileUpload,
  text,
  url,
  googleDrive,
  pdf,
  docx,
  txt,
  image,
  csv,
  xlsx,
  zip;

  String get dbValue => switch (this) {
    IngestionSource.fileUpload  => 'file_upload',
    IngestionSource.googleDrive => 'google_drive',
    _ => name,
  };

  static IngestionSource fromDb(String? value) => switch (value) {
    'file_upload'  => IngestionSource.fileUpload,
    'google_drive' => IngestionSource.googleDrive,
    'manual'       => IngestionSource.manual,
    'library'      => IngestionSource.library,
    'text'         => IngestionSource.text,
    'url'          => IngestionSource.url,
    'pdf'          => IngestionSource.pdf,
    'docx'         => IngestionSource.docx,
    'txt'          => IngestionSource.txt,
    'image'        => IngestionSource.image,
    'csv'          => IngestionSource.csv,
    'xlsx'         => IngestionSource.xlsx,
    'zip'          => IngestionSource.zip,
    _              => IngestionSource.fileUpload,
  };

  String get label => switch (this) {
    IngestionSource.manual      => 'Manual',
    IngestionSource.library     => 'Biblioteca',
    IngestionSource.fileUpload  => 'Arquivo',
    IngestionSource.text        => 'Texto',
    IngestionSource.url         => 'Link/URL',
    IngestionSource.googleDrive => 'Google Drive',
    IngestionSource.pdf         => 'PDF',
    IngestionSource.docx        => 'Word (DOCX)',
    IngestionSource.txt         => 'Texto (.txt)',
    IngestionSource.image       => 'Imagem',
    IngestionSource.csv         => 'CSV',
    IngestionSource.xlsx        => 'Excel (XLSX)',
    IngestionSource.zip         => 'Pacote ZIP',
  };
}

/// Classificação de um item detectado durante a ingestão.
enum IngestionClassification {
  asset,
  resource,
  evidence,
  ignored;

  String get label => switch (this) {
    IngestionClassification.asset    => 'Ativo',
    IngestionClassification.resource => 'Recurso',
    IngestionClassification.evidence => 'Evidência',
    IngestionClassification.ignored  => 'Ignorar',
  };

  String get description => switch (this) {
    IngestionClassification.asset    => 'Será criado como um novo ativo estratégico',
    IngestionClassification.resource => 'Será vinculado como recurso de um ativo existente',
    IngestionClassification.evidence => 'Será registrado como evidência/referência',
    IngestionClassification.ignored  => 'Não será importado',
  };
}

/// Estado de uma sessão de ingestão.
enum IngestionStatus {
  selecting,
  importing,
  parsing,
  classifying,
  checkingDuplicates,
  awaitingConfirmation,
  creating,
  completed,
  cancelled,
  failed;
}
