/// Catalog of downloadable on-device models.
///
/// All files are official LiquidAI GGUF builds and run on llama.cpp
/// (lfm2 architecture, ChatML-style embedded template).
class LocalModel {
  const LocalModel({
    required this.id,
    required this.label,
    required this.description,
    required this.repoId,
    required this.fileName,
    required this.downloadBytes,
    required this.ramMiBHint,
  });

  final String id;
  final String label;
  final String description;
  final String repoId;
  final String fileName;
  final int downloadBytes;
  final int ramMiBHint;

  String get url =>
      'https://huggingface.co/$repoId/resolve/main/$fileName';
}

class LocalModels {
  LocalModels._();

  static const LocalModel lfm25_1_2b = LocalModel(
    id: 'lfm25-1.2b-instruct-q4k_m',
    label: 'LFM2.5 1.2B (Lite)',
    description: 'Small brain, fast on any phone.',
    repoId: 'LiquidAI/LFM2.5-1.2B-Instruct-GGUF',
    fileName: 'LFM2.5-1.2B-Instruct-Q4_K_M.gguf',
    downloadBytes: 730895168,
    ramMiBHint: 1330,
  );

  static const LocalModel lfm25_2_6b = LocalModel(
    id: 'lfm25-2.6b-q4k_m',
    label: 'LFM2.5 2.6B (Cozy)',
    description: 'Richer personality, needs a beefier phone.',
    repoId: 'LiquidAI/LFM2.5-2.6B-GGUF',
    fileName: 'LFM2.5-2.6B-Q4_K_M.gguf',
    downloadBytes: 1674455040,
    ramMiBHint: 2600,
  );

  static const LocalModel defaultModel = lfm25_1_2b;

  static const List<LocalModel> all = <LocalModel>[
    lfm25_1_2b,
    lfm25_2_6b,
  ];

  static LocalModel byId(String? id) {
    for (final LocalModel model in all) {
      if (model.id == id) {
        return model;
      }
    }
    return defaultModel;
  }
}
