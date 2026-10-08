import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const DaenApp());
}

// -----------------------------------------------------------------------------
// الألوان الثابتة للتطبيق
// -----------------------------------------------------------------------------
class AppColors {
  static const Color brand = Color(0xFF0D6B5E);
  static const Color brand2 = Color(0xFF12907D);
  static const Color deep = Color(0xFF0A2E2C);
  static const Color gold = Color(0xFFE3A72F);
  static const Color owe = Color(0xFFC2492F);
  static const Color paid = Color(0xFF1F9D5C);

  // Light Theme
  static const Color bgLight = Color(0xFFEAF0EE);
  static const Color cardLight = Colors.white;
  static const Color inkLight = Color(0xFF12302F);
  static const Color mutedLight = Color(0xFF6A8280);
  static const Color lineLight = Color(0xFFDBE6E3);
  static const Color softLight = Color(0xFFEAF5F2);

  // Dark Theme
  static const Color bgDark = Color(0xFF0B1716);
  static const Color cardDark = Color(0xFF12211F);
  static const Color inkDark = Color(0xFFE6F0EE);
  static const Color mutedDark = Color(0xFF8FA8A4);
  static const Color lineDark = Color(0xFF223936);
  static const Color softDark = Color(0xFF17302D);
}

// -----------------------------------------------------------------------------
// نماذج البيانات (Models)
// -----------------------------------------------------------------------------
class TransactionModel {
  final String id;
  final String name;
  final String product;
  final double price;
  final int qty;
  final String month;

  TransactionModel({
    required this.id,
    required this.name,
    required this.product,
    required this.price,
    required this.qty,
    required this.month,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'product': product,
        'price': price,
        'qty': qty,
        'month': month,
      };

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        product: json['product'] ?? '',
        price: (json['price'] as num).toDouble(),
        qty: (json['qty'] as num).toInt(),
        month: json['month'] ?? '',
      );
}

class PaymentModel {
  final String id;
  final String name;
  final double amount;
  final String note;
  final String date;

  PaymentModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.note,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'amount': amount,
        'note': note,
        'date': date,
      };

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] ?? '',
        date: json['date'] ?? '',
      );
}

// -----------------------------------------------------------------------------
// التطبيق الرئيسي
// -----------------------------------------------------------------------------
class DaenApp extends StatefulWidget {
  const DaenApp({super.key});

  @override
  State<DaenApp> createState() => _DaenAppState();
}

class _DaenAppState extends State<DaenApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'دائن - إدارة الديون',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: AppColors.bgLight,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        fontFamily: 'Tajawal',
        scaffoldBackgroundColor: AppColors.bgDark,
        brightness: Brightness.dark,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: HomeScreen(
          toggleTheme: _toggleTheme,
          isDark: _themeMode == ThemeMode.dark,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// الشاشة الرئيسية
// -----------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDark;

  const HomeScreen({super.key, required this.toggleTheme, required this.isDark});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<String> months = [
    "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
    "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
  ];

  List<TransactionModel> tx = [];
  List<PaymentModel> pays = [];
  String? selectedCreditor;

  final _dNameController = TextEditingController();
  final _pNameController = TextEditingController();
  final _pPriceController = TextEditingController();
  final _pQtyController = TextEditingController(text: '1');
  final _payAmtController = TextEditingController();
  final _payNoteController = TextEditingController();

  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = months[DateTime.now().month - 1];
    _loadData();
    _payAmtController.addListener(() => setState(() {}));
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? txStr = prefs.getString('pos_transactions');
    final String? paysStr = prefs.getString('pos_payments');

    setState(() {
      if (txStr != null) {
        tx = (jsonDecode(txStr) as List).map((e) => TransactionModel.fromJson(e)).toList();
      }
      if (paysStr != null) {
        pays = (jsonDecode(paysStr) as List).map((e) => PaymentModel.fromJson(e)).toList();
      }
      _refreshCreditors();
    });
  }

  Future<void> _persistData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pos_transactions', jsonEncode(tx.map((e) => e.toJson()).toList()));
    await prefs.setString('pos_payments', jsonEncode(pays.map((e) => e.toJson()).toList()));
  }

  List<String> get names => [...{...tx.map((e) => e.name.trim()), ...pays.map((e) => e.name.trim())}];

  Map<String, double> getTotals(String name) {
    final total = tx.where((t) => t.name.trim() == name).fold(0.0, (s, t) => s + (t.price * t.qty));
    final paid = pays.where((p) => p.name.trim() == name).fold(0.0, (s, p) => s + p.amount);
    final rem = (total - paid <= 0) ? 0.0 : ((total - paid) * 100).round() / 100;
    return {'total': total, 'paid': paid, 'rem': rem};
  }

  void _refreshCreditors({String? keepName}) {
    final list = names;
    if (keepName != null && list.contains(keepName)) {
      selectedCreditor = keepName;
    } else if (list.isNotEmpty) {
      selectedCreditor = list.first;
    } else {
      selectedCreditor = null;
    }
  }

  void _showToast(String msg, {bool isErr = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
        ),
        backgroundColor: isErr ? AppColors.owe : AppColors.deep,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
    );
  }

  void _addPurchase() {
    final name = _dNameController.text.trim();
    final product = _pNameController.text.trim();
    final price = double.tryParse(_pPriceController.text) ?? 0.0;
    final qty = int.tryParse(_pQtyController.text) ?? 0;

    if (name.isEmpty) return _showToast('اكتب اسم الدائن', isErr: true);
    if (product.isEmpty) return _showToast('اكتب اسم المنتج', isErr: true);
    if (price <= 0) return _showToast('أدخل سعراً صحيحاً', isErr: true);
    if (qty < 1) return _showToast('أدخل كمية صحيحة', isErr: true);

    final newItem = TransactionModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      product: product,
      price: price,
      qty: qty,
      month: _selectedMonth,
    );

    setState(() {
      tx.add(newItem);
      _persistData();
      _refreshCreditors(keepName: name);
      _pNameController.clear();
      _pPriceController.clear();
      _pQtyController.text = '1';
    });

    _showToast('✅ تم الحفظ بنجاح');
  }

  void _addPayment(double amount, String note) {
    if (selectedCreditor == null) return;
    final name = selectedCreditor!;
    final totals = getTotals(name);
    final rem = totals['rem']!;

    if (amount <= 0) return _showToast('أدخل مبلغاً صحيحاً', isErr: true);
    if (rem == 0) return _showToast('لا يوجد مبلغ متبقٍّ على هذا الدائن', isErr: true);
    if (amount > rem + 0.001) return _showToast('المبلغ أكبر من المتبقي (${rem.toStringAsFixed(2)})', isErr: true);

    final now = DateTime.now();
    final dateStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    setState(() {
      pays.add(PaymentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        amount: amount,
        note: note,
        date: dateStr,
      ));

      if (getTotals(name)['rem'] == 0) {
        tx.removeWhere((t) => t.name.trim() == name);
        pays.removeWhere((p) => p.name.trim() == name);
        _persistData();
        _refreshCreditors();
        _showToast('✅ تم سداد كامل المبلغ وحذف «$name» من السجلات');
      } else {
        _persistData();
        _showToast('تم خصم ${amount.toStringAsFixed(2)} — المتبقي ${getTotals(name)['rem']!.toStringAsFixed(2)}');
      }

      _payAmtController.clear();
      _payNoteController.clear();
    });
  }

  // --- ميزة مشاركة كشف الحساب المصغر ---
  void _shareAccountSummary() {
    if (selectedCreditor == null) {
      _showToast('اختر دائناً أولاً', isErr: true);
      return;
    }
    final name = selectedCreditor!;
    final totals = getTotals(name);

    final String text = "كشف حساب: $name\n"
        "إجمالي المشتريات: ${totals['total']!.toStringAsFixed(2)}\n"
        "المدفوع: ${totals['paid']!.toStringAsFixed(2)}\n"
        "المتبقي: ${totals['rem']!.toStringAsFixed(2)}";

    Share.share(text);
  }

  // --- ميزة طباعة وتصدير التقرير PDF ---
  Future<void> _exportPdf() async {
    if (selectedCreditor == null) {
      _showToast('لا توجد بيانات للتصدير', isErr: true);
      return;
    }

    final name = selectedCreditor!;
    final nameTx = tx.where((t) => t.name.trim() == name).toList();
    final namePays = pays.where((p) => p.name.trim() == name).toList();
    final totals = getTotals(name);

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.tajawalRegular();
    final fontBold = await PdfGoogleFonts.tajawalBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context ctx) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('📋 كشف حساب: $name', style: pw.TextStyle(font: fontBold, fontSize: 20)),
                ),
                pw.SizedBox(height: 20),
                pw.Text('المشتريات:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                pw.SizedBox(height: 8),
                pw.TableHelper.fromTextArray(
                  cellStyle: pw.TextStyle(font: font),headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                  headers: ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
                  data: nameTx.map((t) => [
                    t.month,
                    t.product,
                    '${t.qty}',
                    t.price.toStringAsFixed(2),
                    (t.price * t.qty).toStringAsFixed(2)
                  ]).toList(),
                  headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D6B5E)),
                  alignment: pw.Alignment.center,
                ),
                if (namePays.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('الدفعات:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                  pw.SizedBox(height: 8),
                  pw.TableHelper.fromTextArray(
                    cellStyle: pw.TextStyle(font: font),headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold),
                    headers: ['التاريخ', 'المبلغ', 'ملاحظة'],
                    data: namePays.map((p) => [
                      p.date,
                      p.amount.toStringAsFixed(2),
                      p.note.isEmpty ? '-' : p.note
                    ]).toList(),
                    headerStyle: pw.TextStyle(font: fontBold, color: PdfColors.white),
                    headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF12907D)),
                    alignment: pw.Alignment.center,
                  ),
                ],
                pw.SizedBox(height: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('إجمالي المشتريات:', style: pw.TextStyle(font: font)),
                          pw.Text(totals['total']!.toStringAsFixed(2), style: pw.TextStyle(font: fontBold)),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('إجمالي المدفوع:', style: pw.TextStyle(font: font)),
                          pw.Text(totals['paid']!.toStringAsFixed(2), style: pw.TextStyle(font: fontBold)),
                        ],
                      ),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('المتبقي على الدائن:', style: pw.TextStyle(font: fontBold, fontSize: 14)),
                          pw.Text(totals['rem']!.toStringAsFixed(2), style: pw.TextStyle(font: fontBold, fontSize: 14, color: PdfColors.red800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _wipeAllData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('⚠️ تحذير'),
        content: const Text('سيتم مسح جميع المشتريات والدفعات نهائياً. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                tx.clear();
                pays.clear();
                _persistData();
                _refreshCreditors();
              });
              _showToast('تم تفريغ البيانات', isErr: true);
            },
            child: const Text('مسح الكل', style: TextStyle(color: AppColors.owe)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final lineBg = isDark ? AppColors.lineDark : AppColors.lineLight;
    final softBg = isDark ? AppColors.softDark : AppColors.softLight;
    final inkColor = isDark ? AppColors.inkDark : AppColors.inkLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    final allNames = names;
    final totalSum = tx.fold(0.0, (s, t) => s + (t.price * t.qty));
    final paidSum = pays.fold(0.0, (s, p) => s + p.amount);
    final remSum = allNames.fold(0.0, (s, n) => s + getTotals(n)['rem']!);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 30),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 720),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                children: [
                  _buildHeader(isDark),
                  const SizedBox(height: 12),
                  _buildStatsGrid(allNames.length, totalSum, paidSum, remSum, cardBg, lineBg, mutedColor, softBg),
                  const SizedBox(height: 16),
                  _buildCard(
                    title: '📝 تسجيل مشتريات',
                    cardBg: cardBg,
                    lineBg: lineBg,
                    inkColor: inkColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('اسم الدائن', mutedColor),
                        Autocomplete<String>(
                          optionsBuilder: (textEditingValue) {
                            if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                            return allNames.where((n) => n.contains(textEditingValue.text));
                          },
                          fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                            _dNameController.text = controller.text;
                            return TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: _inputDeco('اختر أو اكتب اسماً جديداً', lineBg, softBg),
                              onChanged: (val) => _dNameController.text = val,
                            );
                          },
                          onSelected: (val) => _dNameController.text = val,
                        ),
                        const SizedBox(height: 12),
                        _buildLabel('المنتج', mutedColor),
                        TextField(
                          controller: _pNameController,
                          decoration: _inputDeco('سكر، شاي، زيت...', lineBg, softBg),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('السعر', mutedColor),
                                  TextField(
                                    controller: _pPriceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: _inputDeco('0.00', lineBg, softBg),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('الكمية', mutedColor),
                                  TextField(
                                    controller: _pQtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: _inputDeco('1', lineBg, softBg),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildLabel('شهر الشراء', mutedColor),
                        DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: _inputDeco('', lineBg, softBg),
                          items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (v) => setState(() => _selectedMonth = v!),
                        ),
                        const SizedBox(height: 16),
                        _buildButton(
                          text: '➕ إضافة إلى حساب الدائن',
                          onPressed: _addPurchase,
                          gradient: const LinearGradient(colors: [AppColors.brand, AppColors.brand2]),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  _buildCard(
                    title: '👤 كشف حساب الدائن',
                    cardBg: cardBg,
                    lineBg: lineBg,
                    inkColor: inkColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: softBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: lineBg),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel('اختر الدائن', mutedColor),
                              DropdownButtonFormField<String>(
                                value: selectedCreditor,
                                decoration: _inputDeco('', lineBg, cardBg),
                                items: allNames.isEmpty
                                    ? [const DropdownMenuItem(value: null, child: Text('لا يوجد دائنون بعد'))]
                                    : allNames.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                                onChanged: (v) => setState(() {
                                  selectedCreditor = v;
                                }),
                              ),
                            ],
                          ),
                        ),

                        if (selectedCreditor != null) ...[
                          const SizedBox(height: 16),
                          _buildPayBox(selectedCreditor!, lineBg, cardBg, mutedColor, softBg),
                          const SizedBox(height: 16),
                          _buildAccountStatement(selectedCreditor!, cardBg, lineBg, mutedColor, softBg),
                        ],

                        // --- أزرار PDF والمشاركة وتفريغ البيانات ---
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildButton(
                                text: '📄 حفظ التقرير PDF',
                                onPressed: _exportPdf,
                                bgColor: softBg,
                                textColor: AppColors.brand2,
                                borderColor: lineBg,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildButton(
                                text: '📤 مشاركة',
                                onPressed: _shareAccountSummary,
                                bgColor: softBg,
                                textColor: AppColors.brand2,
                                borderColor: lineBg,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildButton(
                          text: '🗑️ تفريغ كل البيانات',
                          onPressed: _wipeAllData,
                          bgColor: Colors.transparent,
                          textColor: AppColors.owe,
                          borderColor: AppColors.owe.withOpacity(0.35),
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
    );
  }

  // --- عناصر الواجهة (Widgets) ---
  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 40),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.deep, AppColors.brand],
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
              icon: Text(isDark ? '☀️' : '🌙', style: const TextStyle(fontSize: 22)),
              onPressed: widget.toggleTheme,
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.gold,
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
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(int count, double total, double paid, double rem, Color cardBg, Color lineBg, Color mutedColor, Color softBg) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _buildStatItem('👥', 'عدد الدائنين', '$count', const Color(0xFFFBF0D6), AppColors.gold, cardBg, lineBg, mutedColor),
        _buildStatItem('🧾', 'إجمالي الديون', total.toStringAsFixed(2), softBg, AppColors.brand, cardBg, lineBg, mutedColor),
        _buildStatItem('✅', 'المسدّد', paid.toStringAsFixed(2), const Color(0xFFDCF3E6), AppColors.paid, cardBg, lineBg, mutedColor),
        _buildStatItem('⏳', 'المتبقي', rem.toStringAsFixed(2), const Color(0xFFFBE6E0), AppColors.owe, cardBg, lineBg, mutedColor),
      ],
    );
  }

  Widget _buildStatItem(String icon, String title, String val, Color iconBg, Color valColor, Color cardBg, Color lineBg, Color mutedColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: lineBg),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.bold)),
                Text(val, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: valColor)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPayBox(String name, Color lineBg, Color cardBg, Color mutedColor, Color softBg) {
    final totals = getTotals(name);
    final rem = totals['rem']!;
    final payVal = double.tryParse(_payAmtController.text) ?? 0.0;
    final afterRem = (rem - payVal) < 0 ? 0.0 : (rem - payVal);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paid.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.paid.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💵 دفع جزء من المبلغ', style: TextStyle(color: AppColors.paid, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            width: double.infinity,
            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: lineBg)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontFamily: 'Tajawal', color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                    children: [
                      TextSpan(text: 'المتبقي الحالي على $name: '),
                      TextSpan(text: rem.toStringAsFixed(2), style: const TextStyle(color: AppColors.owe, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (payVal > 0) ...[
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(fontFamily: 'Tajawal', color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                      children: [
                        TextSpan(text: 'بعد دفع ${payVal.toStringAsFixed(2)} يصبح المتبقي: '),
                        TextSpan(text: afterRem.toStringAsFixed(2), style: const TextStyle(color: AppColors.paid, fontWeight: FontWeight.bold)),
                        if (payVal > rem)
                          const TextSpan(text: ' (المبلغ أكبر من المتبقي)', style: TextStyle(color: AppColors.owe)),
                      ],
                    ),
                  ),
                ]
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
                    _buildLabel('المبلغ المدفوع', mutedColor),
                    TextField(
                      controller: _payAmtController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: _inputDeco('0.00', lineBg, cardBg),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('ملاحظة (اختياري)', mutedColor),
                    TextField(
                      controller: _payNoteController,
                      decoration: _inputDeco('دفعة نقدية...', lineBg, cardBg),
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
                child: _buildButton(
                  text: '✔ تسجيل الدفعة',
                  onPressed: () => _addPayment(double.tryParse(_payAmtController.text) ?? 0.0, _payNoteController.text.trim()),
                  gradient: const LinearGradient(colors: [Color(0xFF198A50), Color(0xFF27B36D)]),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildButton(
                  text: 'سداد المتبقي بالكامل',
                  onPressed: () {
                    if (rem > 0) {
                      _addPayment(rem, 'سداد كامل');
                    }
                  },
                  bgColor: softBg,
                  textColor: AppColors.brand2,
                  borderColor: lineBg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatement(String name, Color cardBg, Color lineBg, Color mutedColor, Color softBg) {
    final nameTx = tx.where((t) => t.name.trim() == name).toList();
    final namePays = pays.where((p) => p.name.trim() == name).toList();
    final totals = getTotals(name);
    final total = totals['total']!;
    final paid = totals['paid']!;
    final rem = totals['rem']!;
    final progress = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: Text('📋 كشف حساب: $name', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        const SizedBox(height: 10),
        const Text('المشتريات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 6),
        _buildTable(
          headers: ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي', ''],
          rows: nameTx.map((t) {
            return [
              t.month,
              t.product,
              '${t.qty}',
              t.price.toStringAsFixed(2),
              (t.price * t.qty).toStringAsFixed(2),
              IconButton(
                icon: const Text('🗑️', style: TextStyle(fontSize: 12)),
                onPressed: () => setState(() {
                  tx.removeWhere((item) => item.id == t.id);
                  _persistData();
                  _refreshCreditors(keepName: name);
                }),
              )
            ];
          }).toList(),
          lineBg: lineBg,
          softBg: softBg,
        ),
        if (namePays.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('الدفعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 6),
          _buildTable(
            headers: ['التاريخ', 'المبلغ', 'ملاحظة', ''],
            rows: namePays.map((p) {
              return [
                p.date,
                p.amount.toStringAsFixed(2),
                p.note.isEmpty ? '-' : p.note,
                IconButton(
                  icon: const Text('🗑️', style: TextStyle(fontSize: 12)),
                  onPressed: () => setState(() {
                    pays.removeWhere((item) => item.id == p.id);
                    _persistData();
                    _refreshCreditors(keepName: name);
                  }),
                )
              ];
            }).toList(),
            lineBg: lineBg,
            softBg: softBg,
          ),
        ],
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: lineBg),
          ),
          child: Column(
            children: [
              _buildSumRow('إجمالي المشتريات', total.toStringAsFixed(2), lineBg),
              _buildSumRow('إجمالي المدفوع', paid.toStringAsFixed(2), lineBg),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.deep, AppColors.brand]),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المتبقي على الدائن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      rem.toStringAsFixed(2),
                      style: TextStyle(
                        color: rem == 0 ? const Color(0xFF8DF0B4) : const Color(0xFFFFD37A),
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: lineBg,
            color: AppColors.paid,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: rem == 0 && total > 0 ? const Color(0xFFDCF3E6) : const Color(0xFFFBF0D6),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              rem == 0 && total > 0 ? '✔ تم السداد بالكامل' : 'نسبة السداد ${(progress * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: rem == 0 && total > 0 ? const Color(0xFF157A46) : const Color(0xFF8A6212),
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildTable({required List<String> headers, required List<List<dynamic>> rows, required Color lineBg, required Color softBg}) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: lineBg),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Table(
          border: TableBorder(
            horizontalInside: BorderSide(color: lineBg),
          ),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: BoxDecoration(color: softBg),
              children: headers
                  .map((h) => Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(h, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ))
                  .toList(),
            ),
            if (rows.isEmpty)
              const TableRow(children: [
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('لا توجد بيانات', style: TextStyle(fontSize: 12))),
                ),
                SizedBox(), SizedBox(), SizedBox(), SizedBox(), SizedBox()
              ])
            else
              ...rows.map(
                (row) => TableRow(
                  children: row.map((cell) {
                    if (cell is Widget) return Center(child: cell);
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(cell.toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildSumRow(String label, String val, Color lineBg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: lineBg))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required Widget child, required Color cardBg, required Color lineBg, required Color inkColor}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: lineBg),
        boxShadow: [
          BoxShadow(
            color: AppColors.deep.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: inkColor)),
          const SizedBox(height: 8),
          Divider(color: lineBg, thickness: 1),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildLabel(String text, Color mutedColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: mutedColor)),
    );
  }

  InputDecoration _inputDeco(String hint, Color lineBg, Color bg) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lineBg)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: lineBg)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.brand2, width: 1.5)),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    Gradient? gradient,
    Color? bgColor,
    Color textColor = Colors.white,
    Color? borderColor,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        color: bgColor,
        borderRadius: BorderRadius.circular(13),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Tajawal'),
        ),
      ),
    );
  }
}
