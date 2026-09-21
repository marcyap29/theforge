import '../models/run_session.dart';

/// The kind of "this isn't a real implementation" problem the guard found.
enum CompletionIssue {
  /// Nothing was changed at all.
  none,

  /// No files were applied — nothing was implemented.
  noEdits,

  /// Every applied file is documentation or configuration — no code artifact
  /// was created or edited (the "shell-script fake" / "docs-only commit" case).
  docsConfigOnly,

  /// There is a code file, but every code edit is dominated by placeholder
  /// markers (TODO / simulate / mock) rather than working code.
  placeholderOnly,
}

/// The verdict of the completion guard: whether a Build-with-AI run's applied
/// diff looks like a real implementation, and if not, a plain-English reason.
class CompletionVerdict {
  const CompletionVerdict(this.issue, this.reason);

  final CompletionIssue issue;

  /// Plain-English sentence for the user; empty when [issue] is `none`.
  final String reason;

  bool get suspicious => issue != CompletionIssue.none;
}

/// A deterministic honesty check on what a Build-with-AI run actually changed.
///
/// The NO FAKE COMPLETIONS prompt rule tells the agent not to ship docs, stubs,
/// or `simulate…()` toggles and call a feature done. This is the enforcement
/// counterpart: it inspects the *applied diff* and refuses to let a run be
/// passed off as a real build when the diff is only docs/config or only
/// placeholders — catching a fake even when the model ignores the rule.
///
/// It errs toward silence: the docs/config-only check is precise (it exactly
/// catches the real failures — the "fixed the deploy script" commit that only
/// touched CHANGELOG, the "image recognition" commit that only flipped a
/// config flag). The placeholder check is deliberately conservative so a real
/// implementation that merely contains a stray `// TODO` is never flagged.
class CompletionGuard {
  /// Documentation file extensions — a diff of only these implements nothing.
  static const _docExt = {'.md', '.markdown', '.txt', '.rst', '.adoc'};

  /// Configuration/manifest file extensions.
  static const _configExt = {
    '.yaml', '.yml', '.json', '.toml', '.ini', '.cfg', '.conf', '.lock',
    '.properties', '.plist', '.xml', '.env', '.editorconfig',
  };

  /// Extensionless files that are docs/meta by convention.
  static const _docNames = {
    'changelog', 'readme', 'license', 'licence', 'authors', 'contributors',
    'codeowners', 'notice', 'dockerfile',
  };

  /// Words that, when they dominate the *added* lines of a code file, mean the
  /// "implementation" is a stub/placeholder rather than real code.
  static const _placeholderMarkers = [
    'todo', 'fixme', 'placeholder', 'unimplemented', 'not implemented',
    'notimplemented', 'coming soon', 'simulate', 'stubbed', 'hardcoded',
    'hard-coded',
  ];

  /// Classifies the [applied] edits (the ones actually written this run).
  static CompletionVerdict inspect(List<ProposedEdit> applied) {
    if (applied.isEmpty) {
      return const CompletionVerdict(CompletionIssue.noEdits,
          'No files were changed — nothing was actually implemented.');
    }

    final code = applied.where((e) => !_isDocOrConfig(e.path)).toList();
    if (code.isEmpty) {
      final names = applied.map((e) => _base(e.path)).toSet().take(4).join(', ');
      return CompletionVerdict(
          CompletionIssue.docsConfigOnly,
          'This build only changed docs/config ($names) — no code artifact was '
          'created or edited. Did it actually implement the feature, or just '
          'describe it?');
    }

    // There is at least one code file. Only flag if EVERY code edit is a stub.
    final real = code.where((e) => !_isStub(e)).toList();
    if (real.isEmpty) {
      return const CompletionVerdict(
          CompletionIssue.placeholderOnly,
          'The code changes look like stubs/placeholders (TODO / simulate / '
          '"not implemented") rather than working code. Did it actually build '
          'the feature?');
    }

    return const CompletionVerdict(CompletionIssue.none, '');
  }

  /// True when [path] is a documentation or configuration file.
  static bool _isDocOrConfig(String path) {
    final base = _base(path).toLowerCase();
    if (base.startsWith('.')) return true; // dotfiles: .gitignore, .env, …
    final dot = base.lastIndexOf('.');
    final ext = dot == -1 ? '' : base.substring(dot);
    if (_docExt.contains(ext) || _configExt.contains(ext)) return true;
    final stem = dot == -1 ? base : base.substring(0, dot);
    return _docNames.contains(stem);
  }

  /// True when a code edit's *added* lines are dominated by placeholder markers
  /// — i.e. the markers outnumber the real (non-comment, non-structural) code
  /// lines it adds.
  static bool _isStub(ProposedEdit e) {
    var markerLines = 0;
    var codeLines = 0;
    for (final line in _addedLines(e.oldContent, e.newContent)) {
      final lower = line.toLowerCase();
      if (_placeholderMarkers.any((m) => lower.contains(m))) {
        markerLines++;
      } else if (!_isComment(line) && !_isStructural(line)) {
        codeLines++;
      }
    }
    if (markerLines == 0) return false;
    return codeLines <= markerLines;
  }

  /// Trimmed non-empty lines present in [newContent] but not in [oldContent]
  /// (the closest cheap proxy for "added" lines). A new file's whole body is
  /// "added".
  static List<String> _addedLines(String oldContent, String newContent) {
    final old = oldContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toSet();
    return newContent
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !old.contains(l))
        .toList();
  }

  static bool _isComment(String line) =>
      line.startsWith('//') ||
      line.startsWith('#') ||
      line.startsWith('/*') ||
      line.startsWith('*') ||
      line.startsWith('<!--');

  /// A line made only of structural punctuation (`}`, `);`, `],` …) — scaffolding,
  /// not implementation.
  static bool _isStructural(String line) =>
      RegExp(r'^[{}()\[\];,]+$').hasMatch(line.replaceAll(' ', ''));

  static String _base(String path) {
    final i = path.replaceAll('\\', '/').lastIndexOf('/');
    return i == -1 ? path : path.substring(i + 1);
  }
}
