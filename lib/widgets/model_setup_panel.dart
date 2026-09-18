import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/local_llm/local_models.dart';
import '../services/local_llm/model_manager.dart';

/// Reusable model management card set: download, select, delete, progress.
/// Used by onboarding and the settings screen.
class ModelSetupPanel extends StatelessWidget {
  const ModelSetupPanel({super.key, this.onInstalled});

  /// Called whenever the selected model becomes (or is already) installed.
  final VoidCallback? onInstalled;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ModelManager.instance,
      builder: (BuildContext context, Widget? child) {
        final ModelManager manager = ModelManager.instance;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 8),
            Text(
              'Choose Mochi\'s brain',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Both run fully on this phone, no server needed. Downloads resume where they left off.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final LocalModel model in LocalModels.all) ...<Widget>[
              _ModelCard(
                model: model,
                selected: manager.selected.id == model.id,
                active: manager.state.isActive &&
                    manager.state.model?.id == model.id,
                phase: manager.state.model?.id == model.id
                    ? manager.state.phase
                    : ModelDownloadPhase.idle,
                fraction: manager.state.model?.id == model.id
                    ? manager.state.fraction
                    : 0.0,
                statusMessage: manager.state.model?.id == model.id
                    ? manager.state.message
                    : null,
                onSelect: () async {
                  await manager.selectModel(model);
                  onInstalled?.call();
                },
                onDownload: () async => manager.downloadModel(model),
                onCancel: () async => manager.cancelDownload(),
                onDelete: () async => manager.deleteModel(model),
                onInstalled: onInstalled,
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _ModelCard extends StatelessWidget {
  const _ModelCard({
    required this.model,
    required this.selected,
    required this.active,
    required this.phase,
    required this.fraction,
    required this.onSelect,
    required this.onDownload,
    required this.onCancel,
    required this.onDelete,
    required this.onInstalled,
    this.statusMessage,
  });

  final LocalModel model;
  final bool selected;
  final bool active;
  final ModelDownloadPhase phase;
  final double fraction;
  final Future<void> Function() onSelect;
  final Future<void> Function() onDownload;
  final Future<void> Function() onCancel;
  final Future<void> Function() onDelete;
  final VoidCallback? onInstalled;
  final String? statusMessage;

  String get _sizeLabel =>
      '${(model.downloadBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected
            ? MochiPalette.mint.withValues(alpha: 0.4)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                selected ? Icons.psychology_rounded : Icons.psychology_alt_rounded,
                color: MochiPalette.ink,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      model.label,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${model.description} · $_sizeLabel · '
                      '~${(model.ramMiBHint / 1024).toStringAsFixed(1)} GiB '
                      'RAM',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: MochiPalette.mint,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MochiPalette.ink, width: 2),
                  ),
                  child: Text(
                    'Active',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (phase == ModelDownloadPhase.downloading ||
              phase == ModelDownloadPhase.verifying) ...<Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: phase == ModelDownloadPhase.verifying ? null : fraction,
                minHeight: 12,
                backgroundColor: MochiPalette.ink.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MochiPalette.sky,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    phase == ModelDownloadPhase.verifying
                        ? 'Verifying download...'
                        : '${_formatMb(fraction * model.downloadBytes)} / '
                              '${_formatMb(model.downloadBytes.toDouble())}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: active ? onCancel : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else if (phase == ModelDownloadPhase.failed) ...<Widget>[
            Text(
              'Download failed. Tap to retry.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MochiPalette.peach,
              ),
            ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: active ? null : onDownload,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry download'),
            ),
          ] else ...<Widget>[
            if (statusMessage != null) ...<Widget>[
              Text(
                statusMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: MochiPalette.ink.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    phase == ModelDownloadPhase.done
                        ? 'Ready to use.'
                        : 'Not installed yet',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (phase != ModelDownloadPhase.done)
                  FilledButton.icon(
                    onPressed: active ? null : onDownload,
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download'),
                  )
                else
                  FilledButton(
                    onPressed: () {
                      onSelect();
                      onInstalled?.call();
                    },
                    child: Text(selected ? 'Selected' : 'Use this brain'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _formatMb(double bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
}
