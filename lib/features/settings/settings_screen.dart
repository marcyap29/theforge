import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/llm/llm_model_config.dart';
import '../../services/llm/llm_provider.dart';
import 'settings_notifier.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Failed to load settings: $error'),
          ),
        ),
        data: (state) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              const _SectionHeader('LLM Providers'),
              const _ByokCard(
                providerType: LlmProviderType.gemini,
                displayName: 'Gemini',
                isDefault: true,
              ),
              const SizedBox(height: 12),
              const _ByokCard(
                providerType: LlmProviderType.claude,
                displayName: 'Claude',
              ),
              const SizedBox(height: 12),
              const _ByokCard(
                providerType: LlmProviderType.openai,
                displayName: 'OpenAI',
              ),
              const SizedBox(height: 12),
              const _OllamaCard(),
              const SizedBox(height: 24),
              const _SectionHeader('Model Roles'),
              const _RoleCard(
                role: LlmRole.architect,
                description: 'Spec generation · worksheets',
              ),
              const SizedBox(height: 12),
              const _RoleCard(
                role: LlmRole.executor,
                description: 'Interview turns',
              ),
            ],
          );
        },
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
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
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

class _ProviderCardShell extends StatelessWidget {
  const _ProviderCardShell({
    required this.title,
    required this.status,
    required this.statusColor,
    required this.children,
  });

  final String title;
  final String status;
  final Color statusColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE5E5E7),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Menlo',
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _OllamaCard extends ConsumerStatefulWidget {
  const _OllamaCard();

  @override
  ConsumerState<_OllamaCard> createState() => _OllamaCardState();
}

class _OllamaCardState extends ConsumerState<_OllamaCard> {
  late final TextEditingController _urlController;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    final initial = ref
            .read(settingsProvider)
            .valueOrNull
            ?.settings
            .ollamaBaseUrl ??
        'http://localhost:11434';
    _urlController = TextEditingController(text: initial);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkConnection();
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() => _isChecking = true);
    await ref.read(settingsProvider.notifier).refreshOllama();
    if (mounted) setState(() => _isChecking = false);
  }

  Future<void> _saveUrl() async {
    await ref
        .read(settingsProvider.notifier)
        .setOllamaBaseUrl(_urlController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(settingsProvider).valueOrNull;
    final ollamaStatus = state?.ollamaStatus ?? OllamaStatus.unknown;
    final ollamaModels = state?.ollamaModels ?? const <ModelInfo>[];

    final statusText = switch (ollamaStatus) {
      OllamaStatus.connected => '● Connected',
      OllamaStatus.notRunning => '○ Not running',
      OllamaStatus.unknown => '○ Not checked',
    };
    final statusColor = switch (ollamaStatus) {
      OllamaStatus.connected => const Color(0xFF22C55E),
      OllamaStatus.notRunning => const Color(0xFFEF4444),
      OllamaStatus.unknown => const Color(0xFF9CA3AF),
    };

    return _ProviderCardShell(
      title: 'Ollama (local)',
      status: statusText,
      statusColor: statusColor,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 13,
                  color: Color(0xFFE5E5E7),
                ),
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  isDense: true,
                ),
                onSubmitted: (_) => _saveUrl(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _saveUrl,
              child: const Text('Save'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (ollamaModels.isNotEmpty) ...[
          const Text(
            'Installed models:',
            style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ollamaModels
                .map((m) => _ModelChip(model: m))
                .toList(growable: false),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _isChecking ? null : _checkConnection,
          icon: _isChecking
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 14),
          label: Text(_isChecking ? 'Checking…' : 'Test connection'),
        ),
      ],
    );
  }
}

class _ModelChip extends StatelessWidget {
  const _ModelChip({required this.model});
  final ModelInfo model;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F10),
        border: Border.all(color: const Color(0xFF2C2C2E)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        model.displayName,
        style: const TextStyle(
          fontSize: 11,
          fontFamily: 'Menlo',
          color: Color(0xFFE5E5E7),
        ),
      ),
    );
  }
}

class _ByokCard extends ConsumerStatefulWidget {
  const _ByokCard({
    required this.providerType,
    required this.displayName,
    this.isDefault = false,
  });

  final LlmProviderType providerType;
  final String displayName;
  final bool isDefault;

  @override
  ConsumerState<_ByokCard> createState() => _ByokCardState();
}

class _ByokCardState extends ConsumerState<_ByokCard> {
  final _controller = TextEditingController();
  bool _obscure = true;
  bool _testing = false;
  bool? _testPassed;
  String _testError = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runTest() async {
    if (_testing) return;
    setState(() { _testing = true; _testPassed = null; });
    final error = await ref
        .read(settingsProvider.notifier)
        .testProvider(widget.providerType);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _testPassed = error == null;
      _testError = error ?? '';
    });
  }

  String _maskKey(String key) {
    if (key.length <= 4) return '••••••';
    return '••••••${key.substring(key.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref
        .watch(settingsProvider)
        .valueOrNull
        ?.settings
        .apiKeys[widget.providerType];
    final hasKey = apiKey != null;
    final masked = hasKey ? _maskKey(apiKey) : '';

    return _ProviderCardShell(
      title: widget.isDefault
          ? '${widget.displayName}  (default)'
          : widget.displayName,
      status: hasKey ? '● Configured' : '○ Not configured',
      statusColor:
          hasKey ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF),
      children: [
        TextField(
          controller: _controller,
          obscureText: _obscure,
          style: const TextStyle(
            fontFamily: 'Menlo',
            fontSize: 13,
            color: Color(0xFFE5E5E7),
          ),
          decoration: InputDecoration(
            labelText: 'API key',
            hintText: hasKey ? 'Currently: $masked' : 'Enter key…',
            isDense: true,
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_off : Icons.visibility,
                size: 18,
                color: const Color(0xFF9CA3AF),
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (hasKey)
              TextButton(
                onPressed: () async {
                  await ref
                      .read(settingsProvider.notifier)
                      .clearApiKey(widget.providerType);
                  setState(() { _testPassed = null; _testError = ''; });
                },
                child: const Text('Clear'),
              ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _controller.text.trim().isEmpty
                  ? null
                  : () async {
                      await ref.read(settingsProvider.notifier).setApiKey(
                            widget.providerType,
                            _controller.text,
                          );
                      _controller.clear();
                      setState(() { _testPassed = null; _testError = ''; });
                    },
              child: const Text('Save'),
            ),
          ],
        ),
        if (hasKey) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _runTest,
                icon: _testing
                    ? const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt, size: 14),
                label: Text(_testing ? 'Testing…' : 'Test'),
              ),
              const SizedBox(width: 12),
              if (_testPassed == true)
                const Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF22C55E)),
                    SizedBox(width: 4),
                    Text(
                      'Connected',
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'Menlo',
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ],
                )
              else if (_testPassed == false)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.cancel, size: 14, color: Color(0xFFEF4444)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _testError,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Menlo',
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RoleCard extends ConsumerWidget {
  const _RoleCard({required this.role, required this.description});

  final LlmRole role;
  final String description;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsProvider).valueOrNull;
    if (state == null) return const SizedBox.shrink();

    final settings = state.settings;
    final assignment = settings.roleAssignments[role]!;

    // Always show all providers; missing keys surface as runtime errors in the chat.
    const availableProviders = LlmProviderType.values;

    final models = assignment.providerType == LlmProviderType.ollama
        ? state.ollamaModels
        : modelsFor(assignment.providerType);

    final configured = assignment.modelId.isNotEmpty;

    return _ProviderCardShell(
      title: role == LlmRole.architect ? 'Architect' : 'Executor',
      status: configured ? '● Configured' : '○ Not configured',
      statusColor:
          configured ? const Color(0xFF22C55E) : const Color(0xFF9CA3AF),
      children: [
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<LlmProviderType>(
                initialValue: assignment.providerType,
                items: availableProviders
                    .map(
                      (p) => DropdownMenuItem(
                        value: p,
                        child: Text(p.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (p) async {
                  if (p == null) return;
                  await ref.read(settingsProvider.notifier).setRoleAssignment(
                        role,
                        ModelAssignment(providerType: p, modelId: ''),
                      );
                },
                decoration: const InputDecoration(
                  labelText: 'Provider',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: assignment.modelId.isNotEmpty
                    ? assignment.modelId
                    : null,
                items: models
                    .map(
                      (m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(
                          m.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                onChanged: models.isEmpty
                    ? null
                    : (m) async {
                        if (m == null) return;
                        await ref
                            .read(settingsProvider.notifier)
                            .setRoleAssignment(
                              role,
                              ModelAssignment(
                                providerType: assignment.providerType,
                                modelId: m,
                              ),
                            );
                      },
                decoration: const InputDecoration(
                  labelText: 'Model',
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
