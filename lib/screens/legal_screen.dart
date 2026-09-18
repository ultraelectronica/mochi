import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/legal_documents.dart';

/// Full-screen reader for a single [LegalDocument].
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
        backgroundColor: MochiPalette.background,
        foregroundColor: MochiPalette.ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: pixelCardDecoration(MochiPalette.lavender),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: MochiPalette.cloudBlue,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: MochiPalette.ink,
                              width: 2.5,
                            ),
                          ),
                          child: Icon(
                            document.icon,
                            color: MochiPalette.ink,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            document.title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last updated ${document.lastUpdated}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      document.summary,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    const Divider(
                      color: MochiPalette.ink,
                      thickness: 2,
                      height: 1,
                    ),
                    for (final LegalSection section in document.sections)
                      _LegalSectionView(section: section),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({required this.section});

  final LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(section.heading, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final String paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                paragraph,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}
