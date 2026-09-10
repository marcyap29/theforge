import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One chunk of streamed output from a running command.
class CommandOutput {
  CommandOutput(this.text, {required this.isError});
  final String text;
  final bool isError;
}

/// The result of a finished command.
class CommandResult {
  CommandResult({required this.exitCode});
  final int exitCode;
  bool get ok => exitCode == 0;
}

/// Runs shell commands in the linked repo and STREAMS their stdout/stderr line
/// by line as they arrive — the first use of [Process.start] in the app, and
/// what gives the activity console its live "watch it work" feel.
///
/// A command string is split on top-level whitespace into an executable +
/// args (no shell interpolation), so we don't spawn a shell. This is a
/// deliberate safety choice for a vibecoder audience: every command is shown
/// and approved, then run directly.
class CommandRunner {
  Process? _current;

  bool get isRunning => _current != null;

  /// Patterns we refuse to run even if approved — destructive or self-harming
  /// commands that a non-technical user shouldn't be able to unleash by tapping.
  static final _dangerous = RegExp(
    r'(^|\s|;|&|\|)('
    r'sudo|rm\s+-[rf]|rmdir|mkfs|dd\s|shutdown|reboot|halt|'
    r'kill|killall|pkill|:\(\)\s*\{|chmod\s+-R\s+777|'
    r'>\s*/dev/|git\s+push\s+.*--force|git\s+reset\s+--hard'
    r')(\s|$)',
    caseSensitive: false,
  );

  static bool isDangerous(String raw) => _dangerous.hasMatch(raw);

  /// Runs [raw] in [workingDirectory], invoking [onOutput] for each streamed
  /// line. Completes with the exit code. Never throws — a spawn failure, a
  /// blocked command, or a timeout is surfaced as a non-zero result with a
  /// message streamed to [onOutput]. A per-command [timeout] prevents an
  /// interactive/long-running command from hanging the run forever.
  Future<CommandResult> run(
    String raw, {
    required String workingDirectory,
    required void Function(CommandOutput) onOutput,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    final parts = _tokenize(raw);
    if (parts.isEmpty) {
      return CommandResult(exitCode: 0);
    }
    if (isDangerous(raw)) {
      onOutput(CommandOutput(
          'Blocked: this command is disallowed for safety.', isError: true));
      return CommandResult(exitCode: -2);
    }
    try {
      final process = await Process.start(
        parts.first,
        parts.sublist(1),
        workingDirectory: workingDirectory,
        runInShell: false,
      );
      _current = process;

      final stdoutDone = process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => onOutput(CommandOutput(line, isError: false)))
          .asFuture<void>();
      final stderrDone = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) => onOutput(CommandOutput(line, isError: true)))
          .asFuture<void>();

      var timedOut = false;
      final code = await process.exitCode.timeout(timeout, onTimeout: () {
        timedOut = true;
        process.kill();
        return -1;
      });
      await Future.wait([stdoutDone, stderrDone]).catchError((_) => <void>[]);
      _current = null;
      if (timedOut) {
        onOutput(CommandOutput(
            'Timed out after ${timeout.inSeconds}s — stopped.', isError: true));
      }
      return CommandResult(exitCode: code);
    } catch (e) {
      _current = null;
      onOutput(CommandOutput('Could not run command: $e', isError: true));
      return CommandResult(exitCode: -1);
    }
  }

  /// Kills the currently-running command, if any.
  void cancel() {
    _current?.kill();
    _current = null;
  }

  /// Splits a command line into tokens, honoring simple single/double quotes so
  /// a quoted argument with spaces stays one token. No variable/glob expansion.
  static List<String> _tokenize(String input) {
    final tokens = <String>[];
    final buf = StringBuffer();
    String? quote;
    var hasToken = false;
    for (final rune in input.trim().runes) {
      final ch = String.fromCharCode(rune);
      if (quote != null) {
        if (ch == quote) {
          quote = null;
        } else {
          buf.write(ch);
        }
        hasToken = true;
      } else if (ch == '"' || ch == "'") {
        quote = ch;
        hasToken = true;
      } else if (ch == ' ' || ch == '\t') {
        if (hasToken) {
          tokens.add(buf.toString());
          buf.clear();
          hasToken = false;
        }
      } else {
        buf.write(ch);
        hasToken = true;
      }
    }
    if (hasToken) tokens.add(buf.toString());
    return tokens;
  }
}
