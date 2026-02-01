import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'dictionary_service.dart';

void main() {
  // Configure the proxy URL for secure API access
  // Replace with your deployed Cloudflare Worker URL
  const proxyUrl = String.fromEnvironment(
    'PROXY_URL',
    defaultValue: '', // Empty = use fallback (no AI features)
  );

  if (proxyUrl.isNotEmpty) {
    DictionaryService().setProxyUrl(proxyUrl);
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '汉字 Wordle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121213),
      ),
      home: const GameScreen(),
    );
  }
}
