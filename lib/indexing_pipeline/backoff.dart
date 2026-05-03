import '../gemini_service/gemini_service.dart';

Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 5,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  var attempt = 0;
  var delay = initialDelay;
  while (true) {
    try {
      return await operation();
    } on GeminiRateLimitException {
      attempt++;
      if (attempt >= maxAttempts) rethrow;
      await Future.delayed(delay);
      delay *= 2;
    }
  }
}
