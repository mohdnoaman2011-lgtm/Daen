import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
      ..setBackgroundColor(const Color(0xFFEAF0EE))
      ..addJavaScriptChannel(
        'pdfChannel',
        onMessageReceived: (JavaScriptMessage message) {
          // استقبال اسم الدائن وتوليد ملف PDF عبر فلاتر
          _generateAndSharePdf(message.message);
        },
      )
      ..loadFlutterAsset('assets/index.html');
  }

  // دالة لتوليد وحفظ تقرير الـ PDF بشكل احترافي ومتناسق
  Future<void> _generateAndSharePdf(String creditorName) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'كشف حساب الدائن: $creditorName',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'تم استخراج هذا التقرير عبر تطبيق دائن لإدارة الديون.',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          );
        },
      ),
    );

    // طباعة أو حفظ أو مشاركة ملف الـ PDF مباشرة
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'account_$creditorName.pdf');
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
