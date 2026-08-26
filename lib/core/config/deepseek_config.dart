/// DeepSeek / OpenRouter / Ollama configuration for LLM intent extraction.
///
/// Supply a key at launch (never commit real keys):
///   flutter run --dart-define=OPENROUTER_KEY=sk-or-v1-...
///
/// Works with any OpenAI-compatible endpoint:
///   OpenRouter : https://openrouter.ai/api/v1/chat/completions
///   Ollama     : http://localhost:11434/v1/chat/completions
class DeepSeekConfig {
  static const String apiKey = String.fromEnvironment('OPENROUTER_KEY');
  static const String baseUrl = String.fromEnvironment(
    'LLM_BASE_URL',
    defaultValue: 'https://openrouter.ai/api/v1/chat/completions',
  );
  static const String model = String.fromEnvironment(
    'LLM_MODEL',
    defaultValue: 'google/gemma-4-31b-it:free',
  );

  static bool get isConfigured => apiKey.trim().isNotEmpty;
}
