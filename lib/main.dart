import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const DaenApp());

const months = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
];
const kBrand = Color(0xFF0D6B5E);
const kDeep = Color(0xFF0A2E2C);
const kGold = Color(0xFFE3A72F);
const kOwe = Color(0xFFC2492F);
const kPaid = Color(0xFF1F9D5C);

// ───────────────────────── Models ─────────────────────────
class Purchase {
  final String id, name, product, month;
  final double price;
  final int qty;
  Purchase(this.id, this.name, this.product, this.price, this.qty, this.month);
  double get total => price * qty;
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'product': product,
        'price': price, 'qty': qty, 'month': month
      };
  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
      j['id'] ?? uid(), j['name'], j['product'],
      (j['price'] as num).toDouble(), (j['qty'] as num).toInt(), j['month']);
}

class Payment {
  final String id, name, note, date;
  final double amount;
  Payment(this.id, this.name, this.amount, this.note, this.date);
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'amount': amount, 'note': note, 'date': date};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
      j['id'] ?? uid(), j['name'], (j['amount'] as num).toDouble(),
      j['note'] ?? '', j['date'] ?? '');
}

class Totals {
  final double total, paid, rem;
  Totals(this.total, this.paid)
      : rem = ((total - paid) * 100).round() / 100 < 0
            ? 0
            : ((total - paid) * 100).round() / 100;
}

// ───────────────────────── Helpers ─────────────────────────
String uid() => DateTime.now().microsecondsSinceEpoch.toString();

/// يقبل الأرقام العربية والفارسية والفاصلة العربية
double? parseNum(String s) {
  const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
  var t = s;
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(ar[i], '$i').replaceAll(fa[i], '$i');
  }
  t = t.replaceAll(RegExp('[٫,،]'), '.').replaceAll(RegExp(r'[^0-9.]'), '');
  return double.tryParse(t);
}

String fmt(double n) {
  final p = n.toStringAsFixed(2).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '$i.${p[1]}';
}

// ───────────────────────── App ─────────────────────────
class DaenApp extends StatefulWidget {
  const DaenApp({super.key});
  @override
  State<DaenApp> createState() => _DaenAppState();
}

class _DaenAppState extends State<DaenApp> {
  ThemeMode mode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final t = p.getString('theme');
      if (t != null) {
        setState(() => mode = t == 'dark' ? ThemeMode.dark : ThemeMode.light);
      }
    });
  }

  Future<void> _toggle() async {
    setState(() =>
        mode = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
    final p = await SharedPreferences.getInstance();
    p.setString('theme', mode == ThemeMode.dark ? 'dark' : 'light');
  }

  ThemeData _theme(Brightness b) => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: kBrand, brightness: b),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          isDense: true,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
        ),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'دائن',
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: mode,
        builder: (c, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: HomePage(dark: mode == ThemeMode.dark, onToggle: _toggle),
      );
}

// ───────────────────────── Home ─────────────────────────
class HomePage extends StatefulWidget {
  final bool dark;
  final VoidCallback onToggle;
  const HomePage({super.key, required this.dark, required this.onToggle});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Purchase> tx = [];
  List<Payment> pays = [];
  String? selected;
  String month = months[DateTime.now().month - 1];

  final cName = TextEditingController();
  final cProduct = TextEditingController();
  final cPrice = TextEditingController();
  final cQty = TextEditingController(text: '1');
  final cPay = TextEditingController();
  final cNote = TextEditingController();

  @override
  void initState() {
    super.initState();
    cPay.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    for (final c in [cName, cProduct, cPrice, cQty, cPay, cNote]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── التخزين ──
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    List<T> read<T>(String k, T Function(Map<String, dynamic>) f) {
      try {
        return (jsonDecode(p.getString(k) ?? '[]') as List)
            .map((e) => f(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return [];
      }
    }

    setState(() {
      tx = read('pos_transactions', Purchase.fromJson);
      pays = read('pos_payments', Payment.fromJson);
      _fixSelection();
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'pos_transactions', jsonEncode(tx.map((e) => e.toJson()).toList()));
    await p.setString(
        'pos_payments', jsonEncode(pays.map((e) => e.toJson()).toList()));
  }

  // ── الحسابات ──
  List<String> get names =>
      {...tx.map((e) => e.name.trim()), ...pays.map((e) => e.name.trim())}
          .toList();

  Totals totals(String n) => Totals(
      tx.where((t) => t.name.trim() == n).fold(0.0, (s, t) => s + t.total),
      pays.where((p) => p.name.trim() == n).fold(0.0, (s, p) => s + p.amount));

  void _fixSelection() {
    final l = names;
    if (selected == null || !l.contains(selected)) {
      selected = l.isEmpty ? null : l.first;
    }
  }

  void _msg(String m, {bool err = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: err ? kOwe : kDeep,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<bool> _confirm(String m) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          content: Text(m),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('تأكيد')),
          ],
        ),
      ) ??
      false;

  // ── العمليات ──
  void addPurchase() {
    final name = cName.text.trim(), product = cProduct.text.trim();
    final price = parseNum(cPrice.text), qty = parseNum(cQty.text)?.round();
    if (name.isEmpty) return _msg('اكتب اسم الدائن', err: true);
    if (product.isEmpty) return _msg('اكتب اسم المنتج', err: true);
    if (price == null || price <= 0) return _msg('أدخل سعراً صحيحاً', err: true);
    if (qty == null || qty < 1) return _msg('أدخل كمية صحيحة', err: true);
    setState(() {
      tx.add(Purchase(uid(), name, product, price, qty, month));
      selected = name;
      cProduct.clear();
      cPrice.clear();
      cQty.text = '1';
    });
    _save();
    _msg('✅ تم الحفظ بنجاح');
  }

  void addPayment(double? amount, String note) {
    final n = selected;
    if (n == null) return;
    final rem = totals(n).rem;
    if (amount == null || amount <= 0) {
      return _msg('أدخل مبلغاً صحيحاً', err: true);
    }
    if (rem == 0) return _msg('لا يوجد مبلغ متبقٍّ على هذا الدائن', err: true);
    if (amount > rem + 0.001) {
      return _msg('المبلغ أكبر من المتبقي (${fmt(rem)})', err: true);
    }
    final d = DateTime.now();
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    setState(() {
      pays.add(Payment(uid(), n, amount, note, date));
      cPay.clear();
      cNote.clear();
      if (totals(n).rem == 0) {
        // سداد كامل → حذف الدائن من السجلات
        tx.removeWhere((t) => t.name.trim() == n);
        pays.removeWhere((p) => p.name.trim() == n);
        _fixSelection();
        _msg('✅ تم سداد كامل المبلغ وحذف «$n» من السجلات');
      } else {
        _msg('تم خصم ${fmt(amount)} — المتبقي ${fmt(totals(n).rem)}');
      }
    });
    _save();
  }

  Future<void> deleteTx(String id) async {
    if (!await _confirm('هل تريد حذف هذا السجل؟')) return;
    setState(() {
      tx.removeWhere((t) => t.id == id);
      _fixSelection();
    });
    _save();
  }

  Future<void> deletePay(String id) async {
    if (!await _confirm('هل تريد حذف هذه الدفعة؟')) return;
    setState(() {
      pays.removeWhere((p) => p.id == id);
      _fixSelection();
    });
    _save();
  }

  Future<void> wipe() async {
    if (!await _confirm('⚠️ سيتم مسح جميع المشتريات والدفعات نهائياً. هل أنت متأكد؟')) {
      return;
    }
    setState(() {
      tx = [];
      pays = [];
      selected = null;
    });
    _save();
  }

  void share() {
    final n = selected;
    if (n == null) return _msg('اختر دائناً أولاً', err: true);
    final t = totals(n);
    Share.share('كشف حساب: $n\nإجمالي المشتريات: ${fmt(t.total)}\n'
        'المدفوع: ${fmt(t.paid)}\nالمتبقي: ${fmt(t.rem)}');
  }

  // ── تصدير PDF ──
  Future<void> exportPdf() async {
    final n = selected;
    if (n == null) return _msg('اختر دائناً أولاً', err: true);
    _msg('جارِ تجهيز الملف...');
    try {
      final font = await PdfGoogleFonts.tajawalRegular();
      final bold = await PdfGoogleFonts.tajawalBold();
      final t = totals(n);
      final items = tx.where((e) => e.name.trim() == n).toList()
        ..sort((a, b) => months.indexOf(a.month) - months.indexOf(b.month));
      final ps = pays.where((e) => e.name.trim() == n).toList();
      final b = pw.TextStyle(fontWeight: pw.FontWeight.bold);
      pw.Widget row(String a, String v, {bool strong = false}) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(a, style: strong ? b : null),
                pw.Text(v, style: strong ? b : null),
              ],
            ),
          );

      final doc = pw.Document();
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        margin: const pw.EdgeInsets.all(28),
        build: (c) => [
          pw.Center(
              child: pw.Text('كشف حساب: $n',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.SizedBox(height: 14),
          pw.Text('المشتريات', style: b),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
            data: [
              for (final e in items)
                [e.month, e.product, '${e.qty}', fmt(e.price), fmt(e.total)]
            ],
            headerStyle: b,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
          ),
          if (ps.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            pw.Text('الدفعات', style: b),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['التاريخ', 'المبلغ', 'ملاحظة'],
              data: [
                for (final p in ps)
                  [p.date, fmt(p.amount), p.note.isEmpty ? '-' : p.note]
              ],
              headerStyle: b,
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.center,
            ),
          ],
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
                border: pw.Border.all(), borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Column(children: [
              row('إجمالي المشتريات', fmt(t.total)),
              row('إجمالي المدفوع', fmt(t.paid)),
              pw.Divider(),
              row('المتبقي على الدائن', fmt(t.rem), strong: true),
            ]),
          ),
        ],
      ));
      await Printing.layoutPdf(onLayout: (_) => doc.save(), name: 'statement.pdf');
    } catch (_) {
      _msg('تعذّر إنشاء الملف، تأكد من الاتصال بالإنترنت لتحميل الخط', err: true);
    }
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    final list = names;
    final allTotal = tx.fold(0.0, (s, t) => s + t.total);
    final allPaid = pays.fold(0.0, (s, p) => s + p.amount);
    final allRem = list.fold(0.0, (s, n) => s + totals(n).rem);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.3,
                children: [
                  _stat('👥', 'عدد الدائنين المسجلين', '${list.length}', kGold),
                  _stat('🧾', 'إجمالي الديون', fmt(allTotal), kBrand),
                  _stat('✅', 'المسدّد', fmt(allPaid), kPaid),
                  _stat('⏳', 'المتبقي', fmt(allRem), kOwe),
                ],
              ),
              const SizedBox(height: 14),
              _buyCard(list),
              const SizedBox(height: 14),
              _statementCard(list),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _header() => Container(
        padding: EdgeInsets.fromLTRB(
            20, MediaQuery.of(context).padding.top + 18, 20, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [kDeep, kBrand],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Row(children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: kGold, borderRadius: BorderRadius.circular(15)),
            child: const Text('📒', style: TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('دائن',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),
              Text('سجّل المشتريات والدفعات واعرف المتبقي فوراً',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5)),
            ]),
          ),
          IconButton.filledTonal(
            onPressed: widget.onToggle,
            tooltip: widget.dark ? 'الوضع الفاتح' : 'الوضع الداكن',
            icon: Text(widget.dark ? '☀️' : '🌙',
                style: const TextStyle(fontSize: 20)),
          ),
        ]),
      );

  Widget _stat(String icon, String label, String value, Color color) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: color.withOpacity(.15),
                  borderRadius: BorderRadius.circular(11)),
              child: Text(icon, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5)),
                    FittedBox(
                      child: Text(value,
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: color == kBrand ? null : color)),
                    ),
                  ]),
            ),
          ]),
        ),
      );

  Widget _title(String t, [Color? c]) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: c)),
      );

  Widget _buyCard(List<String> list) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _title('📝 تسجيل مشتريات'),
            TextField(
              controller: cName,
              decoration: const InputDecoration(
                  labelText: 'اسم الدائن', hintText: 'اختر أو اكتب اسماً جديداً'),
            ),
            if (list.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 6, runSpacing: 0, children: [
                  for (final n in list)
                    ActionChip(
                        label: Text(n), onPressed: () => setState(() => cName.text = n)),
                ]),
              ),
            const SizedBox(height: 10),
            TextField(
                controller: cProduct,
                decoration: const InputDecoration(
                    labelText: 'المنتج', hintText: 'سكر، شاي، زيت...')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: cPrice,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'السعر')),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                    controller: cQty,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الكمية')),
              ),
            ]),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: month,
              decoration: const InputDecoration(labelText: 'شهر الشراء'),
              items: [
                for (final m in months) DropdownMenuItem(value: m, child: Text(m))
              ],
              onChanged: (v) => setState(() => month = v ?? month),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: addPurchase,
                icon: const Icon(Icons.add),
                label: const Text('إضافة إلى حساب الدائن'),
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.all(14), backgroundColor: kBrand),
              ),
            ),
          ]),
        ),
      );

  Widget _statementCard(List<String> list) {
    final n = selected;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('👤 كشف حساب الدائن'),
          DropdownButtonFormField<String>(
            value: n,
            decoration: const InputDecoration(labelText: 'اختر الدائن'),
            hint: const Text('لا يوجد دائنون بعد'),
            items: [for (final x in list) DropdownMenuItem(value: x, child: Text(x))],
            onChanged: (v) => setState(() => selected = v),
          ),
          if (n == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('أضف أول عملية شراء لعرض كشف الحساب')),
            )
          else
            ..._statementBody(n),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: exportPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('حفظ التقرير PDF'),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.all(13)),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: share,
                    icon: const Icon(Icons.share),
                    label: const Text('مشاركة'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton.icon(
                    onPressed: wipe,
                    style: OutlinedButton.styleFrom(foregroundColor: kOwe),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('تفريغ الكل'))),
          ]),
        ]),
      ),
    );
  }

  List<Widget> _statementBody(String n) {
    final t = totals(n);
    final items = tx.where((e) => e.name.trim() == n).toList()
      ..sort((a, b) => months.indexOf(a.month) - months.indexOf(b.month));
    final ps = pays.where((e) => e.name.trim() == n).toList();
    final v = parseNum(cPay.text);
    final done = t.rem == 0 && t.total > 0;
    final pct = t.total == 0 ? 0.0 : (t.paid / t.total).clamp(0.0, 1.0);

    return [
      const SizedBox(height: 14),
      // ── خانة الدفع الجزئي ──
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kPaid.withOpacity(.08),
          border: Border.all(color: kPaid.withOpacity(.3)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _title('💵 دفع جزء من المبلغ', kPaid),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'المتبقي الحالي على $n: '),
            TextSpan(
                text: fmt(t.rem),
                style: const TextStyle(color: kOwe, fontWeight: FontWeight.w800)),
            if (v != null && v > 0) ...[
              TextSpan(text: '\nبعد دفع ${fmt(v)} يصبح المتبقي: '),
              TextSpan(
                  text: fmt((t.rem - v) < 0 ? 0 : t.rem - v),
                  style: const TextStyle(
                      color: kPaid, fontWeight: FontWeight.w800)),
              if (v > t.rem + 0.001)
                const TextSpan(
                    text: ' (المبلغ أكبر من المتبقي)',
                    style: TextStyle(color: kOwe)),
            ],
          ])),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                  controller: cPay,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                  controller: cNote,
                  decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)')),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: () => addPayment(parseNum(cPay.text), cNote.text.trim()),
                style: FilledButton.styleFrom(
                    backgroundColor: kPaid, padding: const EdgeInsets.all(13)),
                child: const Text('✔ تسجيل الدفعة'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: t.rem == 0
                    ? null
                    : () async {
                        if (await _confirm('تسجيل سداد كامل بمبلغ ${fmt(t.rem)}؟')) {
                          addPayment(t.rem, 'سداد كامل');
                        }
                      },
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(13)),
                child: const Text('سداد المتبقي'),
              ),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Text('📋 كشف حساب: $n',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      const Text('المشتريات', style: TextStyle(fontWeight: FontWeight.w700)),
      if (items.isEmpty)
        const Padding(padding: EdgeInsets.all(12), child: Text('لا توجد مشتريات')),
      for (final e in items)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text('${e.product}  ×${e.qty}'),
          subtitle: Text('${e.month} • السعر ${fmt(e.price)}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(fmt(e.total), style: const TextStyle(fontWeight: FontWeight.w800)),
            IconButton(
                onPressed: () => deleteTx(e.id),
                icon: const Icon(Icons.delete_outline, color: kOwe, size: 20)),
          ]),
        ),
      if (ps.isNotEmpty) ...[
        const Divider(),
        const Text('الدفعات', style: TextStyle(fontWeight: FontWeight.w700)),
        for (final p in ps)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(fmt(p.amount),
                style: const TextStyle(color: kPaid, fontWeight: FontWeight.w800)),
            subtitle: Text('${p.date}${p.note.isEmpty ? '' : ' • ${p.note}'}'),
            trailing: IconButton(
                onPressed: () => deletePay(p.id),
                icon: const Icon(Icons.delete_outline, color: kOwe, size: 20)),
          ),
      ],
      const SizedBox(height: 10),
      // ── الملخص ──
      Container(
        decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(16)),
        child: Column(children: [
          _sumRow('إجمالي المشتريات', fmt(t.total)),
          _sumRow('إجمالي المدفوع', fmt(t.paid)),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [kDeep, kBrand]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('المتبقي على الدائن',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              Text(fmt(t.rem),
                  style: TextStyle(
                      color: done ? const Color(0xFF8DF0B4) : const Color(0xFFFFD37A),
                      fontWeight: FontWeight.w800,
                      fontSize: 18)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: LinearProgressIndicator(value: pct, minHeight: 10, color: kPaid),
      ),
      const SizedBox(height: 8),
      Center(
        child: Chip(
          label: Text(done ? '✔ تم السداد بالكامل' : 'نسبة السداد ${(pct * 100).round()}%'),
          backgroundColor: done ? const Color(0xFFDCF3E6) : const Color(0xFFFBF0D6),
        ),
      ),
    ];
  }

  Widget _sumRow(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a),
          Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}