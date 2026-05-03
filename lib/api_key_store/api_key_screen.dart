import 'package:flutter/material.dart';
import 'api_key_store.dart';
import 'gemini_key_validator.dart';

class ApiKeyScreen extends StatefulWidget {
  const ApiKeyScreen({
    super.key,
    required this.store,
    required this.validator,
    required this.onKeyAccepted,
  });

  final ApiKeyStore store;
  final GeminiKeyValidator validator;
  final VoidCallback onKeyAccepted;

  @override
  State<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends State<ApiKeyScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final key = _controller.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Please enter your Gemini API key.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await widget.validator.validate(key);

    if (!mounted) return;

    if (!result.valid) {
      setState(() {
        _loading = false;
        _error = result.error != null
            ? 'Could not reach Gemini: ${result.error}'
            : 'Key rejected by Gemini. Check the key and try again.';
      });
      return;
    }

    try {
      await widget.store.save(key);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to save key: $e';
      });
      return;
    }
    if (!mounted) return;
    widget.onKeyAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Gemini API Key')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Context GIF AI uses your Gemini API key to caption your reaction '
              'media and analyse screenshots. The key is stored in your device\'s '
              'secure keychain — never uploaded. Chat screenshots are processed by '
              'Google\'s servers during analysis.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Gemini API key',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Validate & save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
