import 'llm_model_config.dart';

/// Where a provider's keys are managed — used in guidance messages.
String providerKeyHome(LlmProviderType type) => switch (type) {
      LlmProviderType.ollama => 'ollama.com',
      LlmProviderType.claude => 'console.anthropic.com',
      LlmProviderType.openai => 'platform.openai.com',
    };

/// Maps a provider + HTTP status (or a thrown error) from a key test or a
/// failed build into a plain-English, actionable message. Pure — unit-tested.
/// This is the honest counterpart to the raw `Ollama error 401: {...}` that
/// cost a long debugging session (BUG-LLM-002).
String keyErrorGuidance(LlmProviderType type, {int? status, Object? error}) {
  final home = providerKeyHome(type);
  if (status == 401 || status == 403) {
    if (type == LlmProviderType.ollama) {
      return 'Rejected ($status). Your Ollama key is invalid/expired, or your '
          'account isn\'t cleared to run cloud models. Regenerate the key at '
          '$home and check your Cloud plan, then paste it again.';
    }
    return 'Rejected ($status). The API key is invalid or lacks access — '
        'regenerate it at $home and paste it again.';
  }
  if (status == 404) {
    return 'Not found (404). The selected model isn\'t available for this key — '
        'pick a different model.';
  }
  if (status == 429) {
    return 'Rate-limited (429). Too many requests or over quota — wait a moment, '
        'or check billing at $home.';
  }
  if (status != null && status >= 500) {
    return 'Server error ($status) from $home — their side, not yours. '
        'Try again shortly.';
  }
  if (error != null && _looksNetworky(error.toString().toLowerCase())) {
    return 'Couldn\'t reach $home — a network hiccup. Check your connection '
        'and try again.';
  }
  if (error != null) {
    final low = error.toString().toLowerCase();
    if (low.contains('no api key') ||
        low.contains('not configured') ||
        low.contains('no model')) {
      return 'No key or model set for this provider — configure it in Settings.';
    }
    return 'Failed: $error';
  }
  return 'Failed${status != null ? ' (status $status)' : ''}.';
}

/// Rewrites a raw build/LLM error into friendly guidance when it matches a
/// known key/network failure; otherwise returns the original text unchanged
/// (so genuine code/compile errors are never masked). Pure — unit-tested.
String friendlyLlmError(Object error, {LlmProviderType? type}) {
  final raw = error.toString();
  final low = raw.toLowerCase();
  final status = _statusFrom(low);
  final networky = _looksNetworky(low);
  if (status == null && !networky) return raw; // not a key/network error
  return keyErrorGuidance(type ?? _guessProvider(low),
      status: status, error: networky ? error : null);
}

int? _statusFrom(String low) {
  if (low.contains('401') || low.contains('unauthorized')) return 401;
  if (low.contains('403') || low.contains('forbidden')) return 403;
  if (low.contains('404')) return 404;
  if (low.contains('429')) return 429;
  return null;
}

bool _looksNetworky(String low) =>
    low.contains('reset by peer') ||
    low.contains('socketexception') ||
    low.contains('failed host lookup') ||
    low.contains('connection refused') ||
    low.contains('connection closed') ||
    low.contains('timed out') ||
    low.contains('timeout');

LlmProviderType _guessProvider(String low) {
  if (low.contains('claude') || low.contains('anthropic')) {
    return LlmProviderType.claude;
  }
  if (low.contains('openai')) return LlmProviderType.openai;
  return LlmProviderType.ollama; // default (and the common case)
}
