import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ingestion/ingestion_notifier.dart';
import '../ingestion/reference_doc.dart';

class ReferenceDocsScreen extends ConsumerStatefulWidget {
  const ReferenceDocsScreen({super.key, required this.projectPath});

  final String projectPath;

  @override
  ConsumerState<ReferenceDocsScreen> createState() =>
      _ReferenceDocsScreenState();
}

class _ReferenceDocsScreenState extends ConsumerState<ReferenceDocsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(ingestionNotifierProvider.notifier)
          .loadDocs(widget.projectPath);
    });
  }

  Future<void> _pickAndAdd() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'txt'],
    );
    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    if (!mounted) return;
    await ref
        .read(ingestionNotifierProvider.notifier)
        .addDoc(widget.projectPath, filePath);
  }

  Future<void> _remove(String docId) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Remove document?',
            style: TextStyle(color: Color(0xFFE5E5E7))),
        content: const Text(
          'The document and its extracted context will be removed.',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(ingestionNotifierProvider.notifier)
          .removeDoc(widget.projectPath, docId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ingestionNotifierProvider);
    final notifier = ref.read(ingestionNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reference Documents'),
      ),
      body: state.isParsing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFFE8A04C)),
                  SizedBox(height: 16),
                  Text('Extracting reference context…',
                      style: TextStyle(
                          fontFamily: 'Menlo',
                          fontSize: 13,
                          color: Color(0xFF9CA3AF))),
                ],
              ),
            )
          : state.docs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload_file_outlined,
                            size: 48, color: Color(0xFF3F3F46)),
                        const SizedBox(height: 16),
                        const Text(
                          'No reference documents yet.\nAdd .md or .txt files to provide\nbackground context to interviews.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Menlo',
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _pickAndAdd,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Document'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFE8A04C),
                            foregroundColor: const Color(0xFF0F0F10),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (state.error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: const Color(0xFF3F0A0A),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                size: 16, color: Color(0xFFEF4444)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: const TextStyle(
                                    fontFamily: 'Menlo',
                                    fontSize: 11,
                                    color: Color(0xFFFCA5A5)),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  size: 16, color: Color(0xFF9CA3AF)),
                              onPressed: () => notifier.loadDocs(widget.projectPath),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: state.docs.length,
                        itemBuilder: (context, i) {
                          final doc = state.docs[i];
                          return _DocCard(
                            doc: doc,
                            onRemove: () => _remove(doc.id),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: state.isParsing
          ? null
          : FloatingActionButton(
              onPressed: _pickAndAdd,
              backgroundColor: const Color(0xFFE8A04C),
              foregroundColor: const Color(0xFF0F0F10),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc, required this.onRemove});
  final ReferenceDoc doc;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F0F10),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFF2C2C2E)),
        borderRadius: BorderRadius.circular(6),
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 18, color: Color(0xFFE8A04C)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: const TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE5E5E7),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${doc.format.toUpperCase()} · ${doc.wordCount} words',
                    style: const TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: Color(0xFF6B7280)),
              onPressed: onRemove,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}
