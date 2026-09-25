import 'package:flutter_test/flutter_test.dart';
import 'package:the_forge/services/llm/key_check.dart';
import 'package:the_forge/services/llm/llm_model_config.dart';

void main() {
  group('keyErrorGuidance', () {
    test('Ollama 401 points at ollama.com + regenerate + cloud plan', () {
      final m = keyErrorGuidance(LlmProviderType.ollama, status: 401);
      expect(m.toLowerCase(), contains('ollama.com'));
      expect(m.toLowerCase(), contains('regenerate'));
      expect(m.toLowerCase(), contains('cloud'));
    });

    test('Claude/OpenAI 401 points at their console', () {
      expect(keyErrorGuidance(LlmProviderType.claude, status: 401),
          contains('console.anthropic.com'));
      expect(keyErrorGuidance(LlmProviderType.openai, status: 403),
          contains('platform.openai.com'));
    });

    test('404 is about the model, 429 about rate/quota, 5xx is their side', () {
      expect(keyErrorGuidance(LlmProviderType.ollama, status: 404).toLowerCase(),
          contains('model'));
      expect(keyErrorGuidance(LlmProviderType.ollama, status: 429).toLowerCase(),
          contains('rate'));
      expect(keyErrorGuidance(LlmProviderType.ollama, status: 503).toLowerCase(),
          contains('server error'));
    });

    test('a network error reads as a connectivity hiccup', () {
      final m = keyErrorGuidance(LlmProviderType.ollama,
          error: 'ClientException: Connection reset by peer');
      expect(m.toLowerCase(), contains('reach'));
    });
  });

  group('friendlyLlmError', () {
    test('maps the exact BUG-LLM-002 Ollama 401 to actionable guidance', () {
      final m = friendlyLlmError(
          Exception('Ollama error 401: {"error":"Unauthorized"}'));
      expect(m.toLowerCase(), contains('regenerate'));
      expect(m.toLowerCase(), contains('ollama.com'));
      expect(m, isNot(contains('Unauthorized"}'))); // rewritten, not raw
    });

    test('guesses the provider from the error text', () {
      expect(friendlyLlmError(Exception('Claude error 401: bad key')),
          contains('console.anthropic.com'));
      expect(friendlyLlmError(Exception('OpenAI error 401: bad key')),
          contains('platform.openai.com'));
    });

    test('honors an explicit provider type over the guess', () {
      final m = friendlyLlmError(Exception('error 401'),
          type: LlmProviderType.openai);
      expect(m, contains('platform.openai.com'));
    });

    test('a connection reset becomes a network message', () {
      final m = friendlyLlmError(
          Exception('ClientException: Connection reset by peer, '
              'uri=https://ollama.com/api/chat'));
      expect(m.toLowerCase(), contains('reach'));
    });

    test('a non-key/non-network error is returned UNCHANGED', () {
      // e.g. a JSON/compile error must never be masked by friendly text.
      const raw = 'FormatException: Unexpected character at line 3';
      expect(friendlyLlmError(Exception(raw)), contains(raw));
      expect(friendlyLlmError(Exception('did not return valid JSON')),
          contains('did not return valid JSON'));
    });
  });
}
