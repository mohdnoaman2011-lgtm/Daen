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
        'date': '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
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

    var font = await PdfGoogleFonts.cairoRegular();
    var boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('كشف حساب: $selectedCreditor', style: pw.TextStyle(font: boldFont, fontSize: 20)),
              pw.SizedBox(height: 15),
              pw.Text('المشتريات:', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.Table.fromTextArray(
                data: [
                  ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
                  ...cTx.map((t) => [t['month'], t['product'], t['qty'].toString(), t['price'].toString(), ((t['price'] as double) * (t['qty'] as int)).toString()])
                ],
                headerStyle: pw.TextStyle(font: boldFont),
                cellStyle: pw.TextStyle(font: font),
              ),
              pw.SizedBox(height: 15),
              if (cPs.isNotEmpty) ...[
                pw.Text('الدفعات:', style: pw.TextStyle(font: boldFont, fontSize: 14)),
                pw.Table.fromTextArray(
                  data: [
                    ['التاريخ', 'المبلغ', 'ملاحظة'],
                    ...cPs.map((p) => [p['date'], p['amount'].toString(), p['note'] ?? '-'])
                  ],
                  headerStyle: pw.TextStyle(font: boldFont),
                  cellStyle: pw.TextStyle(font: font),
                ),
              ],
              pw.SizedBox(height: 15),
              pw.Divider(),
              pw.Text('إجمالي المشتريات: ${totals['total']}', style: pw.TextStyle(font: boldFont)),
              pw.Text('إجمالي المدفوع: ${totals['paid']}', style: pw.TextStyle(font: boldFont)),
              pw.Text('المتبقي: ${totals['rem']}', style: pw.TextStyle(font: boldFont, color: PdfColors.red)),
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

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 40, 22, 60),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A2E2C), Color(0xFF0D6B5E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: IconButton(
                      icon: Text(widget.isDarkMode ? '☀️' : '🌙', style: const TextStyle(fontSize: 22)),
                      onPressed: widget.onToggleTheme,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3A72F),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Center(child: Text('📒', style: TextStyle(fontSize: 26))),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('دائن', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            Text('سجّل المشتريات والدفعات واعرف المتبقي', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  // Stats Grid
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                      children: [
                        statCard('👥', 'عدد الدائنين', '${names.length}', null),
                        statCard('🧾', 'إجمالي الديون', totalAll.toStringAsFixed(2), null),
                        statCard('✅', 'المسدّد', paidAll.toStringAsFixed(2), const Color(0xFF1F9D5C)),
                        statCard('⏳', 'المتبقي', remAll.toStringAsFixed(2), const Color(0xFFC2492F)),
                      ],
                    ),
                  ),

                  // Add Transaction Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('📝 تسجيل مشتريات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'اسم الدائن',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _productController,
                            decoration: InputDecoration(
                              labelText: 'المنتج (سكر، شاي، زيت...)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _priceController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'السعر',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'الكمية',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: selectedMonth,
                            items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                            onChanged: (val) => setState(() => selectedMonth = val),
                            decoration: InputDecoration(
                              labelText: 'شهر الشراء',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 15),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: addTransaction,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D6B5E),
                                padding: const EdgeInsets.all(14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('➕ إضافة إلى حساب الدائن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Account Statement Card
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('👤 كشف حساب الدائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: names.contains(selectedCreditor) ? selectedCreditor : (names.isNotEmpty ? names.first : null),
                            items: names.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                            onChanged: (val) => setState(() => selectedCreditor = val ?? ''),
                            decoration: InputDecoration(
                              labelText: 'اختر الدائن',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 15),

                          if (selectedCreditor.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.08),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('💵 دفع جزء من المبلغ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1F9D5C))),
                                  const SizedBox(height: 8),
                                  Text('المتبقي الحالي: ${currentTotals['rem']?.toStringAsFixed(2)}'),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _payAmtController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'المبلغ المدفوع',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _payNoteController,
                                          decoration: InputDecoration(
                                            labelText: 'ملاحظة',
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
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
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D5C)),
                                          child: const Text('✔ تسجيل الدفعة', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => addPayment(currentTotals['rem']!, 'سداد كامل'),
                                          child: const Text('سداد بالكامل'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],

                          // Transactions Table Preview
                          const Text('المشتريات:', style: TextStyle(fontWeight: FontWeight.bold)),
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
                                DataColumn(label: Text('حذف')),
                              ],
                              rows: cTx.map((t) => DataRow(cells: [
                                DataCell(Text(t['month'])),
                                DataCell(Text(t['product'])),
                                DataCell(Text(t['qty'].toString())),
                                DataCell(Text(t['price'].toString())),
                                DataCell(Text(((t['price'] as double) * (t['qty'] as int)).toStringAsFixed(2))),
                                DataCell(IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      transactions.removeWhere((item) => item['id'] == t['id']);
                                      saveData();
                                    });
                                  },
                                )),
                              ])).toList(),
                            ),
                          ),

                          const SizedBox(height: 15),
                          // Summary Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                rowSum('إجمالي المشتريات', currentTotals['total']!.toStringAsFixed(2)),
                                rowSum('إجمالي المدفوع', currentTotals['paid']!.toStringAsFixed(2)),
                                rowSum('المتبقي على الدائن', currentTotals['rem']!.toStringAsFixed(2), isBold: true, color: Colors.teal),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          
                          // زر حفظ التقرير PDF وزر المشاركة
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: generatePdf,
                                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                                  label: const Text('📄 حفظ PDF', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6B5E)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: shareAccount,
                                  icon: const Icon(Icons.share, color: Colors.white),
                                  label: const Text('📤 مشاركة', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF12907D)),
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
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('🗑️ تفريغ كل البيانات'),
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
    );
  }

  Widget statCard(String emoji, String title, String value, Color? valColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.isDarkMode ? const Color(0xFF12211F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: widget.isDarkMode ? const Color(0xFF17302D) : const Color(0xFFEAF5F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget rowSum(String title, String val, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
