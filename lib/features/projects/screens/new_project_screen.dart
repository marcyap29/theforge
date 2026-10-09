import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../providers/providers.dart';

class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  final _nameController = TextEditingController();
  String _name = '';
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() => _name = _nameController.text);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_creating) return;
    final name = _name.trim();
    if (name.isEmpty) return;

    setState(() => _creating = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final projectPath = await repo.createProject(name, ProjectMode.build);
      await db.upsertProject(
        ProjectsCompanion.insert(
          id: name,
          name: name,
          path: projectPath,
          mode: ProjectMode.build.name,
          phase: 'tracker',
          createdAt: now,
        ),
      );
      await ref.read(projectListProvider.notifier).refresh();
      if (mounted) navigator.pop();
    } on ProjectAlreadyExistsException {
      if (!mounted) return;
      setState(() => _creating = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text("A project named '$name' already exists."),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to create project: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = _name.trim().isNotEmpty && !_creating;

    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              enabled: !_creating,
              style: const TextStyle(
                fontFamily: 'Menlo',
                fontSize: 13,
                color: Color(0xFFE5E5E7),
              ),
              decoration: InputDecoration(
                hintText: 'e.g. ForkIt, AcmeMobile…',
                hintStyle: const TextStyle(
                  fontFamily: 'Menlo',
                  color: Color(0xFF6B7280),
                ),
                filled: true,
                fillColor: const Color(0xFF0F0F10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFF2C2C2E)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: Color(0xFFE8A04C)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                onPressed: canCreate ? _create : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8A04C),
                  foregroundColor: const Color(0xFF0F0F10),
                ),
                child: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0F0F10),
                        ),
                      )
                    : const Text(
                        'Create',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Menlo',
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
