import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/filesystem/project_file_repository.dart';
import '../../../data/local_db/forge_database.dart';
import '../../../features/settings/settings_providers.dart';
import '../../../services/llm/llm_provider.dart';
import '../../import/import_screen.dart';
import '../providers/providers.dart';

/// How a new project is seeded. The three interview flows map 1:1 to
/// [ProjectMode]; `importDoc` reuses Build mode but routes to the one-shot
/// Import → Spec flow instead of the interview.
enum _Flow { build, audit, pull, importDoc }

class NewProjectScreen extends ConsumerStatefulWidget {
  const NewProjectScreen({super.key});

  @override
  ConsumerState<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends ConsumerState<NewProjectScreen> {
  final _nameController = TextEditingController();
  String _name = '';
  _Flow _flow = _Flow.build;
  bool _creating = false;

  ProjectMode _modeFor(_Flow f) => switch (f) {
        _Flow.build => ProjectMode.build,
        _Flow.importDoc => ProjectMode.build,
        _Flow.audit => ProjectMode.audit,
        _Flow.pull => ProjectMode.pull,
      };

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

    // Projects always live in the fixed canonical root (see
    // ProjectFileRepository._defaultRootDir) — no folder prompt, so the root
    // can never be pointed at a code repo.
    final repo = ref.read(projectFileRepositoryProvider);
    final db = ref.read(forgeDatabaseProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    try {
      final mode = _modeFor(_flow);
      final projectPath = await repo.createProject(name, mode);
      await db.upsertProject(
        ProjectsCompanion.insert(
          id: name,
          name: name,
          path: projectPath,
          mode: mode.name,
          phase: 'v1_interview',
          createdAt: now,
        ),
      );
      await ref.read(projectListProvider.notifier).refresh();
      if (mounted) {
        if (_flow == _Flow.importDoc) {
          navigator.pushReplacement(MaterialPageRoute<void>(
            builder: (_) => ImportScreen(
                projectPath: projectPath, projectName: name),
          ));
        } else {
          navigator.pop();
        }
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
            const _SectionHeader('How to start'),
            _ModeCard(
              icon: Icons.auto_awesome,
              accentColor: const Color(0xFFE8A04C),
              title: 'DESCRIBE A NEW APP',
              tagline: 'Start something new.',
              description:
                  'Paste an idea, doc, or transcript (and optionally a linked '
                  'repo) — the AI drafts the full spec set, you review, then it '
                  'generates.',
              selected: _flow == _Flow.importDoc || _flow == _Flow.build,
              onTap: _creating
                  ? null
                  : () => setState(() => _flow = _Flow.importDoc),
              footer: Row(
                children: [
                  _MethodChip(
                    label: 'Paste an idea',
                    selected: _flow == _Flow.importDoc,
                    onTap: _creating
                        ? null
                        : () => setState(() => _flow = _Flow.importDoc),
                  ),
                  const SizedBox(width: 8),
                  _MethodChip(
                    label: 'Answer guided questions',
                    selected: _flow == _Flow.build,
                    onTap: _creating
                        ? null
                        : () => setState(() => _flow = _Flow.build),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ModeCard(
              icon: Icons.search_outlined,
              accentColor: const Color(0xFFA78BFA),
              title: 'BRING IN EXISTING CODE',
              tagline: 'Onboard a repo you already have.',
              description:
                  'Point The Forge at an existing repo — it analyzes the code '
                  'and starts producing an auditable spec.',
              selected: _flow == _Flow.pull,
              onTap: _creating
                  ? null
                  : () => setState(() => _flow = _Flow.pull),
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
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.tagline,
    required this.description,
    required this.selected,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String tagline;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  /// Optional content shown below the description (e.g. a method sub-toggle).
  final Widget? footer;

  static const _amberBorder = Color(0xFFE8A04C);
  static const _amberBackground = Color(0x1AE8A04C);
  static const _slateBorder = Color(0xFF2C2C2E);
  static const _cardBackground = Color(0xFF1C1C1E);

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? _amberBorder : _slateBorder;
    final backgroundColor = selected ? _amberBackground : _cardBackground;

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
                    icon,
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
              if (footer != null) ...[
                const SizedBox(height: 12),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A small selectable pill used inside a mode card to choose the method
/// (e.g. paste vs guided questions).
class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0x33E8A04C) : const Color(0xFF141416),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? const Color(0xFFE8A04C) : const Color(0xFF2C2C2E),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 13,
              color: selected ? const Color(0xFFE8A04C) : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: selected ? const Color(0xFFE5E5E7) : const Color(0xFF9CA3AF),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
