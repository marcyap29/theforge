import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../features/settings/settings_providers.dart';
import '../../../services/llm/llm_provider.dart';
import '../providers/providers.dart';

class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  final _nameController = TextEditingController();
  String _name = '';
  ProjectMode _mode = ProjectMode.build;
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

    // First-time setup: pick a root folder if none is saved yet.
    final savedRoot = await ProjectFileRepository.getSavedRootPath();
    if (savedRoot == null) {
      final picked = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Choose where to store Forge Projects',
      );
      if (picked != null) {
        await ProjectFileRepository.saveRootPath(picked);
      } else {
        // User dismissed — fall back to default and save it so we don't ask again.
        final docs = await getApplicationDocumentsDirectory();
        await ProjectFileRepository.saveRootPath(
            p.join(docs.path, 'The Forge Projects'));
      }
    }

    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final projectPath = await repo.createProject(name, _mode);
      await db.upsertProject(
        ProjectsCompanion.insert(
          id: name,
          name: name,
          path: projectPath,
          mode: _mode.name,
          phase: 'v1_interview',
          createdAt: now,
        ),
      );
      await ref.read(projectListProvider.notifier).refresh();
      if (mounted) {
        navigator.pop();
      }
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
    final settings = ref.watch(settingsProvider).valueOrNull?.settings;
    final architectAssignment = settings?.roleAssignments[LlmRole.architect];
    final architectKey = architectAssignment != null
        ? settings?.apiKeys[architectAssignment.providerType]
        : null;
    final hasApiKey = architectKey != null && architectKey.isNotEmpty;

    final canCreate = _name.trim().isNotEmpty && !_creating && hasApiKey;

    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!hasApiKey) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C1810),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_off_outlined,
                        color: Color(0xFFEF4444), size: 16),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'No API key configured. Add one in Settings before starting an interview.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFEF4444),
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed('/settings'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Settings →',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE8A04C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const _SectionHeader('Project Name'),
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
            const SizedBox(height: 24),
            const _SectionHeader('Interview Mode'),
            _ModeCard(
              mode: ProjectMode.build,
              title: 'BUILD INTERVIEW',
              tagline: 'Define what gets built.',
              description:
                  'For new products. Produces a locked spec and /goal for '
                  'executor agents.',
              dimensions: const [
                'Core purpose',
                'Identity model',
                'Platform',
                'Scope boundary',
              ],
              selected: _mode == ProjectMode.build,
              onTap: _creating
                  ? null
                  : () => setState(() => _mode = ProjectMode.build),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              mode: ProjectMode.audit,
              title: 'AUDIT INTERVIEW',
              tagline: 'Establish current state.',
              description:
                  'For existing teams/codebases. Produces a Current State Spec '
                  'and blocker registry.',
              dimensions: const [
                'Project goal',
                'Active blockers',
                'Decision debt',
                'AI & token usage',
              ],
              selected: _mode == ProjectMode.audit,
              onTap: _creating
                  ? null
                  : () => setState(() => _mode = ProjectMode.audit),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Color(0xFF9CA3AF),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.mode,
    required this.title,
    required this.tagline,
    required this.description,
    required this.dimensions,
    required this.selected,
    required this.onTap,
  });

  final ProjectMode mode;
  final String title;
  final String tagline;
  final String description;
  final List<String> dimensions;
  final bool selected;
  final VoidCallback? onTap;

  static const _amberBorder = Color(0xFFE8A04C);
  static const _amberBackground = Color(0x1AE8A04C);
  static const _slateBorder = Color(0xFF2C2C2E);
  static const _cardBackground = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? _amberBorder : _slateBorder;
    final backgroundColor = selected ? _amberBackground : _cardBackground;
    final isBuild = mode == ProjectMode.build;
    final accentColor = isBuild ? _amberBorder : const Color(0xFF94A3B8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isBuild ? Icons.build_outlined : Icons.fact_check_outlined,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      fontFamily: 'Menlo',
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tagline,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE5E5E7),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '8 dimensions: ${dimensions.join(', ')}…',
                style: const TextStyle(
                  fontSize: 11,
                  fontFamily: 'Menlo',
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
