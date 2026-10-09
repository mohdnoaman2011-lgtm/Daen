import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دائن - إدارة الديون',
      home: const CreditorAppScreen(),
    );
  }
}

class CreditorAppScreen extends StatefulWidget {
  const CreditorAppScreen({super.key});

  @override
  State<CreditorAppScreen> createState() => _CreditorAppScreenState();
}

class _CreditorAppScreenState extends State<CreditorAppScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadFlutterAsset('assets/index.html'); // تحميل كودك الأصلي كاملاً من الأصول
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
