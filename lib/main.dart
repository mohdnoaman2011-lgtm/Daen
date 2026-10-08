import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'إدارة الحسابات والصيانة',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Map<String, dynamic>> maintenanceRecords = [];
  List<String> namePays = [];
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsString = prefs.getString('maintenance_records');
    if (recordsString != null) {
      setState(() {
        maintenanceRecords = List<Map<String, dynamic>>.from(json.decode(recordsString));
      });
    }
    final String? namesString = prefs.getString('name_pays');
    if (namesString != null) {
      setState(() {
        namePays = List<String>.from(json.decode(namesString));
      });
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('maintenance_records', json.encode(maintenanceRecords));
    await prefs.setString('name_pays', json.encode(namePays));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام إدارة البيانات والصيانة'),
        actions: [
          IconButton(
            icon: Icon(isAdmin ? Icons.admin_panel_settings : Icons.lock),
            onPressed: () {
              setState(() {
                isAdmin = !isAdmin;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(isAdmin ? 'تم تفعيل صلاحيات المشرف' : 'تم قفل صلاحيات المشرف')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () => _generatePdfReport(context),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('تصدير تقرير PDF'),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: maintenanceRecords.length,
                itemBuilder: (context, index) {
                  final record = maintenanceRecords[index];
                  return Card(
                    child: ListTile(
                      title: Text(record['title'] ?? 'بدون عنوان'),
                      subtitle: Text(record['details'] ?? ''),
                      trailing: isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  maintenanceRecords.removeAt(index);
                                  saveData();
                                });
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generatePdfReport(BuildContext context) async {
    final pdf = pw.Document();
    
    var font = await PdfGoogleFonts.cairoRegular();
    var boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'تقرير الصيانة والحسابات',
                  style: pw.TextStyle(font: boldFont, fontSize: 24),
                ),
                pw.SizedBox(height: 20),
                
                pw.Table.fromTextArray(
                  data: <List<String>>[
                    <String>['العنوان', 'التفاصيل', 'الحالة'],
                    ...maintenanceRecords.map((rec) => [
                          rec['title']?.toString() ?? '',
                          rec['details']?.toString() ?? '',
                          rec['status']?.toString() ?? 'مكتمل',
                        ]),
                  ],
                  headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold, color: pw.PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: pw.PdfColors.blue),
                  cellStyle: pw.TextStyle(font: font),
                  cellAlignments: {
                    0: pw.Alignment.center,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                  },
                ),
                
                pw.SizedBox(height: 20),

                if (namePays.isNotEmpty) ...[
                  pw.Text(
                    'قائمة الأسماء والمدفوعات',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Table.fromTextArray(
                    data: <List<String>>[
                      <String>['الرسم التسلسلي', 'الاسم'],
                      ...namePays.asMap().entries.map((entry) => [
                            (entry.key + 1).toString(),
                            entry.value,
                          ]),
                    ],
                    headerStyle: pw.TextStyle(font: boldFont, fontWeight: pw.FontWeight.bold),
                    cellStyle: pw.TextStyle(font: font),
                    cellAlignments: {
                      0: pw.Alignment.center,
                      1: pw.Alignment.center,
                    },
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
