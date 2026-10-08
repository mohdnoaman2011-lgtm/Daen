import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const DaenApp());
}

class DaenApp extends StatefulWidget {
  const DaenApp({super.key});

  @override
  State<DaenApp> createState() => _DaenAppState();
}

class _DaenAppState extends State<DaenApp> {
  bool isDarkMode = false;

  void toggleTheme() {
    setState(() {
      isDarkMode = !isDarkMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دائن - إدارة الديون',
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFEAF0EE),
        primaryColor: const Color(0xFF0D6B5E),
        fontFamily: 'Tajawal',
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0B1716),
        primaryColor: const Color(0xFF0D6B5E),
        fontFamily: 'Tajawal',
      ),
      home: MainScreen(isDarkMode: isDarkMode, onToggleTheme: toggleTheme),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;

  const MainScreen({super.key, required this.isDarkMode, required this.onToggleTheme});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  List<Map<String, dynamic>> transactions = [];
  List<Map<String, dynamic>> payments = [];
  
  final List<String> months = [
    "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
    "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
  ];

  String? selectedMonth;
  String selectedCreditor = '';

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  
  final TextEditingController _payAmtController = TextEditingController();
  final TextEditingController _payNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedMonth = months[DateTime.now().month - 1];
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? txString = prefs.getString('pos_transactions');
    final String? payString = prefs.getString('pos_payments');
    
    setState(() {
      if (txString != null) transactions = List<Map<String, dynamic>>.from(json.decode(txString));
      if (payString != null) payments = List<Map<String, dynamic>>.from(json.decode(payString));
      
      List<String> names = getNames();
      if (names.isNotEmpty && !names.contains(selectedCreditor)) {
        selectedCreditor = names.first;
      }
    });
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_transactions', json.encode(transactions));
    await prefs.setString('pos_payments', json.encode(payments));
  }

  List<String> getNames() {
    Set<String> names = {};
    for (var t in transactions) {
      if (t['name'] != null) names.add(t['name'].toString().trim());
    }
    for (var p in payments) {
      if (p['name'] != null) names.add(p['name'].toString().trim());
    }
    return names.toList();
  }

  Map<String, double> getTotals(String name) {
    double total = transactions
        .where((t) => t['name'].toString().trim() == name)
        .fold(0.0, (sum, t) => sum + ((t['price'] ?? 0) * (t['qty'] ?? 1)));
        
    double paid = payments
        .where((p) => p['name'].toString().trim() == name)
        .fold(0.0, (sum, p) => sum + (p['amount'] ?? 0));
        
    double rem = total - paid;
    if (rem < 0) rem = 0;
    return {'total': total, 'paid': paid, 'rem': rem};
  }

  void showToast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal')),
        backgroundColor: isError ? const Color(0xFFC2492F) : const Color(0xFF0A2E2C),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void addTransaction() {
    String name = _nameController.text.trim();
    String product = _productController.text.trim();
    double price = double.tryParse(_priceController.text) ?? 0;
    int qty = int.tryParse(_qtyController.text) ?? 1;

    if (name.isEmpty) return showToast('اكتب اسم الدائن', isError: true);
    if (product.isEmpty) return showToast('اكتب اسم المنتج', isError: true);
    if (price <= 0) return showToast('أدخل سعراً صحيحاً', isError: true);
    if (qty < 1) return showToast('أدخل كمية صحيحة', isError: true);

    setState(() {
      transactions.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': name,
        'product': product,
        'price': price,
        'qty': qty,
        'month': selectedMonth,
      });
      selectedCreditor = name;
      _productController.clear();
      _priceController.clear();
      _qtyController.text = '1';
      saveData();
    });
    showToast('✅ تم الحفظ بنجاح');
  }

  void addPayment(double amount, String note) {
    if (selectedCreditor.isEmpty) return;
    var totals = getTotals(selectedCreditor);
    double rem = totals['rem']!;

    if (amount <= 0) return showToast('أدخل مبلغاً صحيحاً', isError: true);
    if (rem == 0) return showToast('لا يوجد مبلغ متبقٍّ على هذا الدائن', isError: true);
    if (amount > rem + 0.001) return showToast('المبلغ أكبر من المتبقي', isError: true);

    setState(() {
      payments.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': selectedCreditor,
        'amount': amount,
        'note': note,
        'date': '${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
      });

      if (getTotals(selectedCreditor)['rem'] == 0) {
        transactions.removeWhere((t) => t['name'].toString().trim() == selectedCreditor);
        payments.removeWhere((p) => p['name'].toString().trim() == selectedCreditor);
        saveData();
        showToast('✅ تم سداد كامل المبلغ وحذف الدائن من السجلات');
        List<String> names = getNames();
        selectedCreditor = names.isNotEmpty ? names.first : '';
      } else {
        saveData();
        showToast('تمت إضافة الدفعة بنجاح');
      }
    });
  }

  Future<void> generatePdf() async {
    if (selectedCreditor.isEmpty) {
      showToast('اختر دائناً أولاً', isError: true);
      return;
    }
    final pdf = pw.Document();
    var totals = getTotals(selectedCreditor);
    var cTx = transactions.where((t) => t['name'].toString().trim() == selectedCreditor).toList();
    var cPs = payments.where((p) => p['name'].toString().trim() == selectedCreditor).toList();

    // تحميل وتضمين الخط العربي Cairo بشكل صحيح ليظهر النص بدقة
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text('كشف حساب $selectedCreditor', style: pw.TextStyle(font: boldFont, fontSize: 18)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('المشتريات', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headerAlignments: {0: pw.Alignment.center, 1: pw.Alignment.center, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.center},
                cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.center, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.center},
                headers: ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
                data: cTx.map((t) => [
                  t['month']?.toString() ?? '',
                  t['product']?.toString() ?? '',
                  t['qty']?.toString() ?? '',
                  t['price']?.toString() ?? '',
                  ((t['price'] ?? 0) * (t['qty'] ?? 1)).toStringAsFixed(2),
                ]).toList(),
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 11),
                cellStyle: pw.TextStyle(font: font, fontSize: 10),
              ),
              if (cPs.isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('الدفعات', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.Table.fromTextArray(
                  headerAlignments: {0: pw.Alignment.center, 1: pw.Alignment.center, 2: pw.Alignment.center},
                  cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.center, 2: pw.Alignment.center},
                  headers: ['التاريخ', 'المبلغ', 'ملاحظة'],
                  data: cPs.map((p) => [
                    p['date']?.toString() ?? '',
                    p['amount']?.toString() ?? '',
                    p['note']?.toString().isEmpty ?? true ? '-' : p['note'].toString(),
                  ]).toList(),
                  headerStyle: pw.TextStyle(font: boldFont, fontSize: 11),
                  cellStyle: pw.TextStyle(font: font, fontSize: 10),
                ),
              ],
              pw.SizedBox(height: 25),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي المشتريات', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.Text(totals['total']!.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي المدفوع', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.Text(totals['paid']!.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('المتبقي على الدائن', style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.red)),
                  pw.Text(totals['rem']!.toStringAsFixed(2), style: pw.TextStyle(font: boldFont, fontSize: 13, color: PdfColors.red)),
                ],
              ),
              pw.SizedBox(height: 15),
              pw.Center(
                child: pw.Text(
                  'نسبة السداد ${totals['total']! > 0 ? (totals['paid']! / totals['total']! * 100).round() : 0}%',
                  style: pw.TextStyle(font: boldFont, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  void shareAccount() {
    if (selectedCreditor.isEmpty) {
      showToast('اختر دائناً أولاً', isError: true);
      return;
    }
    var totals = getTotals(selectedCreditor);
    String text = 'كشف حساب: $selectedCreditor\nإجمالي المشتريات: ${totals['total']?.toStringAsFixed(2)}\nالمدفوع: ${totals['paid']?.toStringAsFixed(2)}\nالمتبقي: ${totals['rem']?.toStringAsFixed(2)}';
    Share.share(text);
  }

  @override
  Widget build(BuildContext context) {
    List<String> names = getNames();
    double totalAll = transactions.fold(0.0, (s, t) => s + ((t['price'] ?? 0) * (t['qty'] ?? 1)));
    double paidAll = payments.fold(0.0, (s, p) => s + (p['amount'] ?? 0));
    double remAll = names.fold(0.0, (s, n) => s + getTotals(n)['rem']!);

    var currentTotals = selectedCreditor.isNotEmpty ? getTotals(selectedCreditor) : {'total': 0.0, 'paid': 0.0, 'rem': 0.0};
    var cTx = transactions.where((t) => t['name'].toString().trim() == selectedCreditor).toList();
    var cPs = payments.where((p) => p['name'].toString().trim() == selectedCreditor).toList();
    double totalCreditor = currentTotals['total']!;
    double paidCreditor = currentTotals['paid']!;
    double remCreditor = currentTotals['rem']!;
    double progressRatio = totalCreditor > 0 ? (paidCreditor / totalCreditor).clamp(0.0, 1.0) : 0.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  children: [
                    // Header مطابق تماماً لملف الـ HTML
                    Transform.translate(
                      offset: const Offset(-14, 0),
                      child: Container(
                        width: MediaQuery.of(context).size.width > 720 ? 720 : MediaQuery.of(context).size.width,
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 70),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0A2E2C), Color(0xFF0D6B5E)],
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                          ),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(28),
                            bottomRight: Radius.circular(28),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 16,
                              top: 6,
                              child: InkWell(
                                onTap: widget.onToggleTheme,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                                  ),
                                  child: Center(
                                    child: Text(widget.isDarkMode ? '☀️' : '🌙', style: const TextStyle(fontSize: 20)),
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE3A72F),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 4))],
                                    ),
                                    child: const Center(child: Text('📒', style: TextStyle(fontSize: 26))),
                                  ),
                                  const SizedBox(width: 14),
                                  const Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('دائن', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                                      Text('سجّل المشتريات والدفعات واعرف المتبقي على كل دائن فوراً', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Stats Grid (البطاقات الأربعة)
                    Transform.translate(
                      offset: const Offset(0, -48),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.15,
                        children: [
                          statCard('👥', 'عدد الدائنين المسجلين', '${names.length}', null, false),
                          statCard('🧾', 'إجمالي الديون', totalAll.toStringAsFixed(2), null, false),
                          statCard('✅', 'المسدّد', paidAll.toStringAsFixed(2), const Color(0xFF1F9D5C), true),
                          statCard('⏳', 'المتبقي', remAll.toStringAsFixed(2), const Color(0xFFC2492F), true),
                        ],
                      ),
                    ),

                    // تسجيل مشتريات
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Column(
                        children: [
                          Card(
                            elevation: 0,
                            color: widget.isDarkMode ? const Color(0xFF12211F) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xFFDBE6E3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('📝 تسجيل مشتريات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1, color: Color(0xFFDBE6E3)),
                                  ),
                                  const Text('اسم الدائن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _nameController,
                                    decoration: InputDecoration(
                                      hintText: 'اختر أو اكتب اسماً جديداً',
                                      filled: true,
                                      fillColor: const Color(0xFFEAF0EE),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('المنتج', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _productController,
                                    decoration: InputDecoration(
                                      hintText: 'سكر، شاي، زيت...',
                                      filled: true,
                                      fillColor: const Color(0xFFEAF0EE),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('السعر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _priceController,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                hintText: '0.00',
                                                filled: true,
                                                fillColor: const Color(0xFFEAF0EE),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('الكمية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _qtyController,
                                              keyboardType: TextInputType.number,
                                              decoration: InputDecoration(
                                                filled: true,
                                                fillColor: const Color(0xFFEAF0EE),
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('شهر الشراء', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: selectedMonth,
                                    items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                                    onChanged: (val) => setState(() => selectedMonth = val),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFEAF0EE),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: addTransaction,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0D6B5E),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                        elevation: 8,
                                        shadowColor: const Color(0xB20D6B5E),
                                      ),
                                      child: const Text('➕ إضافة إلى حساب الدائن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // كشف حساب الدائن
                          Card(
                            elevation: 0,
                            color: widget.isDarkMode ? const Color(0xFF12211F) : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: const BorderSide(color: Color(0xFFDBE6E3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('👤 كشف حساب الدائن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1, color: Color(0xFFDBE6E3)),
                                  ),
                                  const Text('اختر الدائن', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                  const SizedBox(height: 6),
                                  DropdownButtonFormField<String>(
                                    value: names.contains(selectedCreditor) ? selectedCreditor : (names.isNotEmpty ? names.first : null),
                                    items: names.isNotEmpty 
                                        ? names.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList()
                                        : [const DropdownMenuItem(value: '', child: Text('لا يوجد دائنون بعد'))],
                                    onChanged: (val) => setState(() => selectedCreditor = val ?? ''),
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: const Color(0xFFEAF0EE),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                    ),
                                  ),
                                  const SizedBox(height: 15),

                                  if (selectedCreditor.isNotEmpty) ...[
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1F9D5C).withOpacity(0.09),
                                        border: Border.all(color: const Color(0xFF1F9D5C).withOpacity(0.25)),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('💵 دفع جزء من المبلغ', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1F9D5C), fontSize: 15)),
                                          const SizedBox(height: 10),
                                          RichText(
                                            text: TextSpan(
                                              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13),
                                              children: [
                                                const TextSpan(text: 'المتبقي الحالي على '),
                                                TextSpan(text: selectedCreditor, style: const TextStyle(fontWeight: FontWeight.bold)),
                                                const TextSpan(text: ': '),
                                                TextSpan(text: remCreditor.toStringAsFixed(2), style: const TextStyle(color: Color(0xFFC2492F), fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('المبلغ المدفوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                                    const SizedBox(height: 4),
                                                    TextField(
                                                      controller: _payAmtController,
                                                      keyboardType: TextInputType.number,
                                                      decoration: InputDecoration(
                                                        hintText: '0.00',
                                                        filled: true,
                                                        fillColor: const Color(0xFFEAF0EE),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('ملاحظة (اختياري)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6A8280))),
                                                    const SizedBox(height: 4),
                                                    TextField(
                                                      controller: _payNoteController,
                                                      decoration: InputDecoration(
                                                        hintText: 'دفعة نقدية...',
                                                        filled: true,
                                                        fillColor: const Color(0xFFEAF0EE),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFDBE6E3))),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    double amt = double.tryParse(_payAmtController.text) ?? 0;
                                                    addPayment(amt, _payNoteController.text);
                                                    _payAmtController.clear();
                                                    _payNoteController.clear();
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF1F9D5C),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                  child: const Text('✔ تسجيل الدفعة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => addPayment(remCreditor, 'سداد كامل'),
                                                  style: OutlinedButton.styleFrom(
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    side: const BorderSide(color: Color(0xFFDBE6E3)),
                                                  ),
                                                  child: const Text('سداد المتبقي بالكامل', style: TextStyle(fontSize: 11)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                  ],

                                  // تفاصيل الكشف وجداول المشتريات والدفعات
                                  const Center(child: Text('كشف حساب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                                  const SizedBox(height: 10),
                                  const Text('المشتريات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 6),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('الشهر')),
                                        DataColumn(label: Text('المنتج')),
                                        DataColumn(label: Text('الكمية')),
                                        DataColumn(label: Text('السعر')),
                                        DataColumn(label: Text('الإجمالي')),
                                        DataColumn(label: Text('')),
                                      ],
                                      rows: cTx.isNotEmpty ? cTx.map((t) => DataRow(cells: [
                                        DataCell(Text(t['month']?.toString() ?? '')),
                                        DataCell(Text(t['product']?.toString() ?? '')),
                                        DataCell(Text(t['qty']?.toString() ?? '')),
                                        DataCell(Text(t['price']?.toString() ?? '')),
                                        DataCell(Text(((t['price'] ?? 0) * (t['qty'] ?? 1)).toStringAsFixed(2))),
                                        DataCell(IconButton(
                                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                          onPressed: () {
                                            setState(() {
                                              transactions.removeWhere((item) => item['id'] == t['id']);
                                              saveData();
                                            });
                                          },
                                        )),
                                      ])).toList() : const [
                                        DataRow(cells: [
                                          DataCell(Text('')), DataCell(Text('')), DataCell(Text('أضف أول عملية شراء لعرض كشف الحساب')), DataCell(Text('')), DataCell(Text('')), DataCell(Text(''))
                                        ])
                                      ],
                                    ),
                                  ),

                                  if (cPs.isNotEmpty) ...[
                                    const SizedBox(height: 15),
                                    const Text('الدفعات', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    const SizedBox(height: 6),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        columns: const [
                                          DataColumn(label: Text('التاريخ')),
                                          DataColumn(label: Text('المبلغ')),
                                          DataColumn(label: Text('ملاحظة')),
                                          DataColumn(label: Text('')),
                                        ],
                                        rows: cPs.map((p) => DataRow(cells: [
                                          DataCell(Text(p['date']?.toString() ?? '')),
                                          DataCell(Text(p['amount']?.toString() ?? '', style: const TextStyle(color: Color(0xFF1F9D5C), fontWeight: FontWeight.bold))),
                                          DataCell(Text(p['note']?.toString() ?? '-')),
                                          DataCell(IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                            onPressed: () {
                                              setState(() {
                                                payments.removeWhere((item) => item['id'] == p['id']);
                                                saveData();
                                              });
                                            },
                                          )),
                                        ])).toList(),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 15),

                                  // الملخص النهائي
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: const Color(0xFFDBE6E3)),
                                    ),
                                    child: Column(
                                      children: [
                                        sumRow('إجمالي المشتريات', totalCreditor.toStringAsFixed(2)),
                                        sumRow('إجمالي المدفوع', paidCreditor.toStringAsFixed(2)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(colors: [Color(0xFF0A2E2C), Color(0xFF0D6B5E)]),
                                            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('المتبقي على الدائن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                                              Text(remCreditor.toStringAsFixed(2), style: TextStyle(color: remCreditor == 0 ? const Color(0xFF8DF0B4) : const Color(0xFFFFD37A), fontWeight: FontWeight.w800, fontSize: 16)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),
                                  // شريط التقدم
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value: progressRatio,
                                      minHeight: 10,
                                      backgroundColor: const Color(0xFFDBE6E3),
                                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1F9D5C)),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: remCreditor == 0 && totalCreditor > 0 ? const Color(0xFFDCF3E6) : const Color(0xFFFBF0D6),
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                      child: Text(
                                        remCreditor == 0 && totalCreditor > 0 ? '✔ تم السداد بالكامل' : 'نسبة السداد ${(progressRatio * 100).round()}%',
                                        style: TextStyle(
                                          color: remCreditor == 0 && totalCreditor > 0 ? const Color(0xFF157A46) : const Color(0xFF8A6212),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 20),

                                  // أزرار حفظ التقرير PDF ومشاركة بمقاسات مطابقة تماماً
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: generatePdf,
                                          icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF12907D), size: 20),
                                          label: const Text('حفظ التقرير\nPDF', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF12907D), fontWeight: FontWeight.bold, fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEAF5F2),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 11),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: Color(0xFFDBE6E3))),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: shareAccount,
                                          icon: const Icon(Icons.share, color: Color(0xFF12907D), size: 20),
                                          label: const Text('مشاركة', style: TextStyle(color: Color(0xFF12907D), fontWeight: FontWeight.bold, fontSize: 13)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFFEAF5F2),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(vertical: 17),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13), side: const BorderSide(color: Color(0xFFDBE6E3))),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          transactions.clear();
                                          payments.clear();
                                          saveData();
                                        });
                                        showToast('تم تفريغ البيانات', isError: true);
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFC2492F),
                                        padding: const EdgeInsets.symmetric(vertical: 13),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                                        side: const BorderSide(color: Color(0xFFFBE6E0)),
                                      ),
                                      child: const Text('🗑️ تفريغ كل البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget statCard(String emoji, String title, String value, Color? valColor, bool isColored) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF12211F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDBE6E3)),
        boxShadow: const [BoxShadow(color: Color(0x0A0A2E2C), blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isColored 
                  ? (valColor == const Color(0xFF1F9D5C) ? const Color(0xFFDCF3E6) : const Color(0xFFFBE6E0))
                  : const Color(0xFFEAF5F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF6A8280), fontWeight: FontWeight.bold)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: valColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget sumRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
