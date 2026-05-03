import 'package:flutter/material.dart';
import 'api_key_store/api_key_screen.dart';
import 'api_key_store/api_key_store.dart';
import 'api_key_store/gemini_key_validator.dart';

void main() {
  runApp(const ContextGifApp());
}

class ContextGifApp extends StatelessWidget {
  const ContextGifApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Context GIF AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const _StartupRouter(),
    );
  }
}

class _StartupRouter extends StatefulWidget {
  const _StartupRouter();

  @override
  State<_StartupRouter> createState() => _StartupRouterState();
}

class _StartupRouterState extends State<_StartupRouter> {
  final _store = ApiKeyStore();
  late final _validator = GeminiKeyValidator();

  bool _checked = false;
  bool _hasKey = false;

  @override
  void initState() {
    super.initState();
    _checkKey();
  }

  Future<void> _checkKey() async {
    final key = await _store.retrieve();
    setState(() {
      _hasKey = key != null;
      _checked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasKey) {
      return ApiKeyScreen(
        store: _store,
        validator: _validator,
        onKeyAccepted: () => setState(() => _hasKey = true),
      );
    }
    return const ShellPage();
  }
}

class ShellPage extends StatelessWidget {
  const ShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Context GIF AI'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: const Center(
        child: Text('Coming soon', style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
