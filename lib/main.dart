import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ───────────────────────── الألوان (نفس متغيرات CSS) ─────────────────────────
class P {
  final bool d;
  P(this.d);
  Color get bg => d ? const Color(0xFF0B1716) : const Color(0xFFEAF0EE);
  Color get card => d ? const Color(0xFF12211F) : Colors.white;
  Color get ink => d ? const Color(0xFFE6F0EE) : const Color(0xFF12302F);
  Color get muted => d ? const Color(0xFF8FA8A4) : const Color(0xFF6A8280);
  Color get line => d ? const Color(0xFF223936) : const Color(0xFFDBE6E3);
  Color get soft => d ? const Color(0xFF17302D) : const Color(0xFFEAF5F2);
  static const brand = Color(0xFF0D6B5E);
  static const brand2 = Color(0xFF12907D);
  static const deep = Color(0xFF0A2E2C);
  static const gold = Color(0xFFE3A72F);
  static const owe = Color(0xFFC2492F);
  static const paid = Color(0xFF1F9D5C);
  List<BoxShadow> get sh => [
        BoxShadow(
            color: d ? const Color(0x99000000) : const Color(0x2E0A2E2C),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: -10),
      ];
}

const months = [
  "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
  "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"
];

// ───────────────────────── النماذج ─────────────────────────
class Tx {
  String id, name, product, month;
  double price;
  int qty;
  Tx(this.id, this.name, this.product, this.price, this.qty, this.month);
  double get total => price * qty;
  Map<String, dynamic> toJson() => {
        'id': id, 'name': name, 'product': product,
        'price': price, 'qty': qty, 'month': month
      };
  factory Tx.fromJson(Map j) => Tx(
      (j['id'] ?? uid()).toString(), j['name'].toString(),
      j['product'].toString(), (j['price'] as num).toDouble(),
      (j['qty'] as num).toInt(), j['month'].toString());
}

class Pay {
  String id, name, note, date;
  double amount;
  Pay(this.id, this.name, this.amount, this.note, this.date);
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'amount': amount, 'note': note, 'date': date};
  factory Pay.fromJson(Map j) => Pay(
      (j['id'] ?? uid()).toString(), j['name'].toString(),
      (j['amount'] as num).toDouble(), (j['note'] ?? '').toString(),
      (j['date'] ?? '').toString());
}

int _c = 0;
String uid() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) + (_c++).toString();

double? numP(String v) {
  var t = v;
  const a = '٠١٢٣٤٥٦٧٨٩', b = '۰۱۲۳۴۵۶۷۸۹';
  for (var i = 0; i < 10; i++) {
    t = t.replaceAll(a[i], '$i').replaceAll(b[i], '$i');
  }
  t = t.replaceAll(RegExp('[٫,،]'), '.').replaceAll(RegExp('[^0-9.]'), '');
  return double.tryParse(t);
}

String fmt(double n) {
  final r = (n * 100).round() / 100;
  final p = r.toStringAsFixed(2).split('.');
  final i = p[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  return '$i.${p[1]}';
}

final darkN = ValueNotifier<bool>(false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sp = await SharedPreferences.getInstance();
  final t = sp.getString('theme');
  darkN.value = t != null
      ? t == 'dark'
      : WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  runApp(const DaenApp());
}

class DaenApp extends StatelessWidget {
  const DaenApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: darkN,
      builder: (_, dark, __) {
        final br = dark ? Brightness.dark : Brightness.light;
        final base = ThemeData(
            brightness: br,
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: P.brand, brightness: br));
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'دائن - إدارة الديون',
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: base.copyWith(
              textTheme: GoogleFonts.tajawalTextTheme(base.textTheme)),
          builder: (c, w) {
            final mq = MediaQuery.of(c);
            return MediaQuery(
              data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.1)),
              child: Directionality(textDirection: TextDirection.rtl, child: w!),
            );
          },
          home: const Home(),
        );
      },
    );
  }
}

// ───────────────────────── الشاشة الرئيسية ─────────────────────────
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Tx> tx = [];
  List<Pay> pays = [];
  String? sel;
  String month = months[DateTime.now().month - 1];
  final dName = TextEditingController(),
      pName = TextEditingController(),
      pPrice = TextEditingController(),
      pQty = TextEditingController(text: '1'),
      payAmt = TextEditingController(),
      payNote = TextEditingController();
  final dFocus = FocusNode();
  late P c;
  SharedPreferences? sp;

  TextStyle t(double s,
          {FontWeight w = FontWeight.w500, Color? color, double? h}) =>
      GoogleFonts.tajawal(
          fontSize: s, fontWeight: w, color: color ?? c.ink, height: h);

  @override
  void initState() {
    super.initState();
    payAmt.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    sp = await SharedPreferences.getInstance();
    try {
      tx = (jsonDecode(sp!.getString('pos_transactions') ?? '[]') as List)
          .map((e) => Tx.fromJson(e))
          .toList();
      pays = (jsonDecode(sp!.getString('pos_payments') ?? '[]') as List)
          .map((e) => Pay.fromJson(e))
          .toList();
    } catch (_) {}
    setState(_fixSel);
  }

  void _persist() {
    sp?.setString('pos_transactions', jsonEncode(tx.map((e) => e.toJson()).toList()));
    sp?.setString('pos_payments', jsonEncode(pays.map((e) => e.toJson()).toList()));
  }

  List<String> get names =>
      {...tx.map((e) => e.name.trim()), ...pays.map((e) => e.name.trim())}
          .toList();

  void _fixSel() {
    final n = names;
    if (sel == null || !n.contains(sel)) sel = n.isEmpty ? null : n.first;
  }

  ({double total, double paid, double rem}) totals(String n) {
    final total =
        tx.where((e) => e.name.trim() == n).fold(0.0, (s, e) => s + e.total);
    final paid =
        pays.where((e) => e.name.trim() == n).fold(0.0, (s, e) => s + e.amount);
    final rem = ((total - paid) * 100).round() / 100;
    return (total: total, paid: paid, rem: rem < 0 ? 0 : rem);
  }

  void toast(String m, {bool err = false}) {
    final s = ScaffoldMessenger.of(context);
    s.hideCurrentSnackBar();
    s.showSnackBar(SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(milliseconds: 2500),
      content: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: P.deep,
            borderRadius: BorderRadius.circular(30),
            border: Border(
                bottom: BorderSide(color: err ? P.owe : P.paid, width: 3)),
          ),
          child: Text(m, style: t(14.4, w: FontWeight.w700, color: Colors.white)),
        ),
      ),
    ));
  }

  Future<bool> confirm(String msg) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: c.card,
        content: Text(msg, style: t(15, w: FontWeight.w700)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('إلغاء', style: t(14, w: FontWeight.w700, color: c.muted))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('تأكيد', style: t(14, w: FontWeight.w800, color: P.brand2))),
        ],
      ),
    );
    return r ?? false;
  }

  // ───────── العمليات ─────────
  void addPurchase() {
    final name = dName.text.trim(), product = pName.text.trim();
    final price = numP(pPrice.text), qty = numP(pQty.text)?.round();
    if (name.isEmpty) return toast('اكتب اسم الدائن', err: true);
    if (product.isEmpty) return toast('اكتب اسم المنتج', err: true);
    if (price == null || !(price > 0)) return toast('أدخل سعراً صحيحاً', err: true);
    if (qty == null || qty < 1) return toast('أدخل كمية صحيحة', err: true);
    tx.add(Tx(uid(), name, product, price, qty, month));
    _persist();
    setState(() {
      sel = name;
      pName.clear();
      pPrice.clear();
      pQty.text = '1';
    });
    FocusScope.of(context).unfocus();
    toast('✅ تم الحفظ بنجاح');
  }

  void addPayment(double? amount, String note) {
    final n = sel;
    if (n == null) return;
    final rem = totals(n).rem;
    if (amount == null || !(amount > 0)) return toast('أدخل مبلغاً صحيحاً', err: true);
    if (rem == 0) return toast('لا يوجد مبلغ متبقٍّ على هذا الدائن', err: true);
    if (amount > rem + 0.001) return toast('المبلغ أكبر من المتبقي (${fmt(rem)})', err: true);
    final d = DateTime.now();
    final date =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    pays.add(Pay(uid(), n, amount, note, date));
    if (totals(n).rem == 0) {
      tx.removeWhere((e) => e.name.trim() == n);
      pays.removeWhere((e) => e.name.trim() == n);
      _persist();
      setState(_fixSel);
      toast('✅ تم سداد كامل المبلغ وحذف «$n» من السجلات');
      return;
    }
    _persist();
    setState(() {});
    toast('تم خصم ${fmt(amount)} — المتبقي ${fmt(totals(n).rem)}');
  }

  // ───────── PDF (يُرسم بمحرك Flutter لضمان سلامة الحروف العربية) ─────────
  Widget _report(String n, List<Tx> items, List<Pay> ps, double total, double paid, double rem) {
    const ink = Color(0xFF12302F);
    const muted = Color(0xFF6A8280);
    const lineC = Color(0xFFDBE6E3);
    TextStyle s(double z, {FontWeight w = FontWeight.w500, Color color = ink}) =>
        GoogleFonts.tajawal(fontSize: z, fontWeight: w, color: color);
    Widget tbl(List<String> heads, List<List<String>> rows) => Table(
          border: TableBorder.all(color: lineC),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFEAF5F2)),
              children: heads
                  .map((h) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Center(child: Text(h, style: s(12, w: FontWeight.w700, color: muted)))))
                  .toList(),
            ),
            for (final r in rows)
              TableRow(
                children: r
                    .map((v) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Center(child: Text(v, style: s(12)))))
                    .toList(),
              ),
          ],
        );
    Widget sr(String a, String b, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: last ? P.brand : null,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(a, style: s(13, w: last ? FontWeight.w800 : FontWeight.w500, color: last ? Colors.white : ink)),
            Text(b, style: s(13, w: last ? FontWeight.w800 : FontWeight.w500, color: last ? Colors.white : ink)),
          ]),
        );
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: ThemeData.light(),
        child: Material(
          color: Colors.white,
          child: SizedBox(
            width: 595,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: Text('كشف حساب: $n', style: s(20, w: FontWeight.w800))),
                  const SizedBox(height: 16),
                  Text('المشتريات', style: s(14, w: FontWeight.w800)),
                  const SizedBox(height: 6),
                  tbl(['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
                      items.map((e) => [e.month, e.product, '${e.qty}', fmt(e.price), fmt(e.total)]).toList()),
                  if (ps.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('الدفعات', style: s(14, w: FontWeight.w800)),
                    const SizedBox(height: 6),
                    tbl(['التاريخ', 'المبلغ', 'ملاحظة'],
                        ps.map((e) => [e.date, fmt(e.amount), e.note.isEmpty ? '-' : e.note]).toList()),
                  ],
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: lineC)),
                    child: Column(children: [
                      sr('إجمالي المشتريات', fmt(total)),
                      const Divider(height: 1, color: lineC),
                      sr('إجمالي المدفوع', fmt(paid)),
                      sr('المتبقي على الدائن', fmt(rem), last: true),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> exportPdf() async {
    final n = sel;
    if (n == null) return toast('لا توجد بيانات للتصدير', err: true);
    toast('جارٍ تجهيز التقرير...');
    try {
      final items = tx.where((e) => e.name.trim() == n).toList()
        ..sort((a, b) => months.indexOf(a.month) - months.indexOf(b.month));
      final ps = pays.where((e) => e.name.trim() == n).toList();
      final tt = totals(n);
      final bytes = await ScreenshotController().captureFromLongWidget(
        _report(n, items, ps, tt.total, tt.paid, tt.rem),
        context: context,
        pixelRatio: 3,
        delay: const Duration(milliseconds: 400),
        constraints: const BoxConstraints(maxWidth: 595),
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final img = (await codec.getNextFrame()).image;
      const a4 = PdfPageFormat.a4;
      final fmtPage = PdfPageFormat(a4.width, a4.height, marginAll: 0);
      final sliceH = (img.width * a4.height / a4.width).floor();
      final doc = pw.Document();
      for (var y = 0; y < img.height; y += sliceH) {
        final h = (img.height - y) < sliceH ? img.height - y : sliceH;
        final rec = ui.PictureRecorder();
        Canvas(rec).drawImageRect(
          img,
          Rect.fromLTWH(0, y.toDouble(), img.width.toDouble(), h.toDouble()),
          Rect.fromLTWH(0, 0, img.width.toDouble(), h.toDouble()),
          Paint()..filterQuality = FilterQuality.high,
        );
        final si = await rec.endRecording().toImage(img.width, h);
        final png = (await si.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        final mi = pw.MemoryImage(png);
        doc.addPage(pw.Page(
          pageFormat: fmtPage,
          build: (_) => pw.Align(
              alignment: pw.Alignment.topCenter,
              child: pw.Image(mi, width: a4.width)),
        ));
      }
      await Printing.layoutPdf(name: 'كشف حساب $n', onLayout: (_) => doc.save());
    } catch (e) {
      toast('تعذّر إنشاء التقرير', err: true);
    }
  }

  Future<void> share() async {
    final n = sel;
    if (n == null) return toast('اختر دائناً أولاً', err: true);
    final r = totals(n);
    await Share.share(
        'كشف حساب: $n\nإجمالي المشتريات: ${fmt(r.total)}\nالمدفوع: ${fmt(r.paid)}\nالمتبقي: ${fmt(r.rem)}');
  }

  // ───────── عناصر مساعدة ─────────
  Widget card({required Widget child, String? title}) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.line),
          boxShadow: c.sh,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (title != null) ...[
            Text(title, style: t(16.3, w: FontWeight.w800)),
            const SizedBox(height: 10),
            _dashed(),
            const SizedBox(height: 14),
          ],
          child,
        ]),
      );

  Widget _dashed() => LayoutBuilder(builder: (_, k) {
        final n = (k.maxWidth / 7).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
              n, (_) => Container(width: 4, height: 1, color: c.line)),
        );
      });

  InputDecoration deco(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: t(15, color: c.muted.withOpacity(.7)),
        filled: true,
        fillColor: c.bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.line, width: 1.5)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: c.line, width: 1.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: P.brand2, width: 1.5)),
      );

  Widget field(TextEditingController ctl,
          {String? hint, TextInputType? kb, FocusNode? fn}) =>
      TextField(
          controller: ctl,
          focusNode: fn,
          keyboardType: kb,
          style: t(15.4),
          decoration: deco(hint));

  Widget labeled(String l, Widget w) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l, style: t(12.8, w: FontWeight.w700, color: c.muted)),
          const SizedBox(height: 6),
          w,
        ]),
      );

  Widget drop(String? v, List<String> items, ValueChanged<String?> on,
          {String? hint}) =>
      DropdownButtonFormField<String>(
        value: items.contains(v) ? v : null,
        isExpanded: true,
        dropdownColor: c.card,
        style: t(15.4),
        icon: Icon(Icons.keyboard_arrow_down, color: c.muted),
        decoration: deco(hint),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: t(15.4))))
            .toList(),
        onChanged: items.isEmpty ? null : on,
      );

  Widget btn(String label, VoidCallback on, {String kind = 'main'}) {
    final main = kind == 'main' || kind == 'pay';
    final grad = kind == 'pay'
        ? const [Color(0xFF198A50), Color(0xFF27B36D)]
        : const [P.brand, P.brand2];
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: main ? LinearGradient(colors: grad) : null,
          color: kind == 'alt' ? c.soft : null,
          borderRadius: BorderRadius.circular(13),
          border: kind == 'alt'
              ? Border.all(color: c.line)
              : kind == 'danger'
                  ? Border.all(color: P.owe.withOpacity(.35))
                  : null,
          boxShadow: main
              ? [BoxShadow(color: grad[0].withOpacity(.55), blurRadius: 16, offset: const Offset(0, 8), spreadRadius: -8)]
              : null,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: on,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Center(
              child: Text(label,
                  style: t(15.4, w: FontWeight.w800,
                      color: main ? Colors.white : kind == 'alt' ? P.brand2 : P.owe)),
            ),
          ),
        ),
      ),
    );
  }

  Widget stat(String ic, String label, String val, Color icBg, Color? vc, bool wide) {
    final icon = Container(
      width: 40, height: 40,
      decoration: BoxDecoration(color: icBg, borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Text(ic, style: const TextStyle(fontSize: 19)),
    );
    final al = wide ? Alignment.center : AlignmentDirectional.centerStart;
    final txt = [
      FittedBox(fit: BoxFit.scaleDown, alignment: al, child: Text(label, maxLines: 1, style: t(11.8, color: c.muted))),
      FittedBox(fit: BoxFit.scaleDown, alignment: al, child: Text(val, maxLines: 1, style: t(18.4, w: FontWeight.w800, color: vc))),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
        boxShadow: c.sh,
      ),
      child: wide
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [icon, const SizedBox(height: 6), ...txt])
          : Row(children: [
              icon,
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: txt)),
            ]),
    );
  }

  Widget dataTable(List<String> heads, List<List<Widget>> rows, String empty) {
    Widget cell(Widget w) => Padding(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10), child: Center(child: w));
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: rows.isEmpty
          ? Padding(padding: const EdgeInsets.all(22), child: Center(child: Text(empty, style: t(13.6, color: c.muted))))
          : LayoutBuilder(
              builder: (_, k) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: k.maxWidth),
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(flex: 1),
                    border: TableBorder(horizontalInside: BorderSide(color: c.line)),
                    children: [
                      TableRow(
                        decoration: BoxDecoration(color: c.soft),
                        children: heads.map((h) => cell(Text(h, style: t(12.5, w: FontWeight.w700, color: c.muted)))).toList(),
                      ),
                      for (var i = 0; i < rows.length; i++)
                        TableRow(
                          decoration: BoxDecoration(color: i.isOdd ? P.brand2.withOpacity(.04) : null),
                          children: rows[i].map(cell).toList(),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget delBtn(VoidCallback on) => InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: on,
        child: const Padding(padding: EdgeInsets.all(4), child: Opacity(opacity: .7, child: Text('🗑️', style: TextStyle(fontSize: 16)))),
      );

  // ───────── البناء ─────────
  @override
  Widget build(BuildContext context) {
    c = P(darkN.value);
    final wide = MediaQuery.of(context).size.width >= 640;
    final list = names;
    final T = tx.fold(0.0, (s, e) => s + e.total);
    final PA = pays.fold(0.0, (s, e) => s + e.amount);
    final R = list.fold(0.0, (s, n) => s + totals(n).rem);
    final top = MediaQuery.of(context).padding.top;

    final stats = [
      stat('👥', 'عدد الدائنين المسجلين', '${list.length}', const Color(0xFFFBF0D6), null, wide),
      stat('🧾', 'إجمالي الديون', fmt(T), c.soft, null, wide),
      stat('✅', 'المسدّد', fmt(PA), const Color(0xFFDCF3E6), P.paid, wide),
      stat('⏳', 'المتبقي', fmt(R), const Color(0xFFFBE6E0), P.owe, wide),
    ];
    final statsH = wide ? 110.0 : 150.0;

    return Scaffold(
      backgroundColor: c.bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 90),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              _header(top),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(children: [
                  SizedBox(
                    height: statsH - 48 + 16,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Positioned(
                        top: -48, left: 0, right: 0, height: statsH,
                        child: wide
                            ? Row(children: [
                                for (var i = 0; i < 4; i++) ...[
                                  if (i > 0) const SizedBox(width: 10),
                                  Expanded(child: stats[i]),
                                ]
                              ])
                            : Column(children: [
                                Expanded(child: Row(children: [Expanded(child: stats[0]), const SizedBox(width: 10), Expanded(child: stats[1])])),
                                const SizedBox(height: 10),
                                Expanded(child: Row(children: [Expanded(child: stats[2]), const SizedBox(width: 10), Expanded(child: stats[3])])),
                              ]),
                      ),
                    ]),
                  ),
                  _buyCard(list),
                  _accountCard(list),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header(double top) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(22, 26 + top, 22, 70),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [P.deep, P.brand]),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned(left: -62, top: -76 - top, child: Container(width: 190, height: 190, decoration: BoxDecoration(shape: BoxShape.circle, color: P.gold.withOpacity(.18)))),
          Positioned(left: 38, bottom: -96, child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.07)))),
          Row(children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: P.gold, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 14, offset: Offset(0, 6))]),
              alignment: Alignment.center,
              child: const Text('📒', style: TextStyle(fontSize: 25)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('دائن', style: t(24, w: FontWeight.w800, color: Colors.white)),
                Text('سجّل المشتريات والدفعات واعرف المتبقي على كل دائن فوراً',
                    style: t(13.6, color: Colors.white.withOpacity(.8))),
              ]),
            ),
          ]),
          Positioned(
            left: -6, top: -10,
            child: Material(
              color: Colors.white.withOpacity(.12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.white.withOpacity(.25))),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() => darkN.value = !darkN.value);
                  sp?.setString('theme', darkN.value ? 'dark' : 'light');
                },
                child: SizedBox(width: 44, height: 44, child: Center(child: Text(darkN.value ? '☀️' : '🌙', style: const TextStyle(fontSize: 20)))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buyCard(List<String> list) {
    return card(
      title: '📝 تسجيل مشتريات',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        labeled(
          'اسم الدائن',
          LayoutBuilder(
            builder: (_, k) => RawAutocomplete<String>(
              textEditingController: dName,
              focusNode: dFocus,
              optionsBuilder: (v) => names.where((n) => n.contains(v.text.trim())),
              fieldViewBuilder: (_, ctl, fn, __) => field(ctl, fn: fn, hint: 'اختر أو اكتب اسماً جديداً'),
              optionsViewBuilder: (ctx, onSel, opts) => Align(
                alignment: AlignmentDirectional.topStart,
                child: Material(
                  elevation: 4,
                  color: c.card,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 200, maxWidth: k.maxWidth),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: opts.map((o) => ListTile(dense: true, title: Text(o, style: t(15)), onTap: () => onSel(o))).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        labeled('المنتج', field(pName, hint: 'سكر، شاي، زيت...')),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: labeled('السعر', field(pPrice, hint: '0.00', kb: const TextInputType.numberWithOptions(decimal: true)))),
          const SizedBox(width: 10),
          Expanded(child: labeled('الكمية', field(pQty, kb: TextInputType.number))),
        ]),
        labeled('شهر الشراء', drop(month, months, (v) => setState(() => month = v ?? month))),
        btn('➕ إضافة إلى حساب الدائن', addPurchase),
      ]),
    );
  }

  Widget _accountCard(List<String> list) {
    final n = sel;
    final items = n == null
        ? <Tx>[]
        : (tx.where((e) => e.name.trim() == n).toList()
          ..sort((a, b) => months.indexOf(a.month) - months.indexOf(b.month)));
    final ps = n == null ? <Pay>[] : pays.where((e) => e.name.trim() == n).toList();
    final r = n == null ? (total: 0.0, paid: 0.0, rem: 0.0) : totals(n);
    final done = r.rem == 0 && r.total > 0;
    final pct = r.total > 0 ? (r.paid / r.total).clamp(0.0, 1.0) : 0.0;

    return card(
      title: '👤 كشف حساب الدائن',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(13),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: c.soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('اختر الدائن', style: t(12.8, w: FontWeight.w700, color: c.muted)),
            const SizedBox(height: 6),
            drop(n, list, (v) => setState(() => sel = v), hint: 'لا يوجد دائنون بعد'),
          ]),
        ),
        if (n != null) _payBox(n, r.rem),
        Center(child: Text(n == null ? 'كشف حساب' : '📋 كشف حساب: $n', style: t(17.3, w: FontWeight.w800))),
        const SizedBox(height: 14),
        Text('المشتريات', style: t(14.7, w: FontWeight.w800)),
        dataTable(
          ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي', ''],
          items.map((e) => <Widget>[
                Text(e.month, style: t(13.6, w: FontWeight.w700)),
                Text(e.product, style: t(13.6)),
                Text('${e.qty}', style: t(13.6)),
                Text(fmt(e.price), style: t(13.6)),
                Text(fmt(e.total), style: t(13.6, w: FontWeight.w800)),
                delBtn(() async {
                  if (!await confirm('هل تريد حذف هذا السجل؟')) return;
                  tx.removeWhere((x) => x.id == e.id);
                  _persist();
                  setState(_fixSel);
                  toast('تم الحذف', err: true);
                }),
              ]).toList(),
          n == null ? 'أضف أول عملية شراء لعرض كشف الحساب' : 'لا توجد مشتريات',
        ),
        if (ps.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('الدفعات', style: t(14.7, w: FontWeight.w800)),
          dataTable(
            ['التاريخ', 'المبلغ', 'ملاحظة', ''],
            ps.map((e) => <Widget>[
                  Text(e.date, style: t(13.6)),
                  Text(fmt(e.amount), style: t(13.6, w: FontWeight.w800, color: P.paid)),
                  Text(e.note.isEmpty ? '-' : e.note, style: t(13.6)),
                  delBtn(() async {
                    if (!await confirm('هل تريد حذف هذا السجل؟')) return;
                    pays.removeWhere((x) => x.id == e.id);
                    _persist();
                    setState(_fixSel);
                    toast('تم الحذف', err: true);
                  }),
                ]).toList(),
            '',
          ),
        ],
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _sumRow('إجمالي المشتريات', fmt(r.total)),
              Divider(height: 1, color: c.line),
              _sumRow('إجمالي المدفوع', fmt(r.paid)),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [P.deep, P.brand])),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('المتبقي على الدائن', style: t(17.6, w: FontWeight.w800, color: Colors.white)),
                  Text(fmt(r.rem), style: t(17.6, w: FontWeight.w800, color: r.rem == 0 ? const Color(0xFF8DF0B4) : const Color(0xFFFFD37A))),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (_, k) => Container(
            height: 10,
            decoration: BoxDecoration(color: c.line, borderRadius: BorderRadius.circular(10)),
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: k.maxWidth * pct,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [P.paid, Color(0xFF6FDC9F)]),
              ),
            ),
          ),
        ),
        if (n != null)
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: done ? const Color(0xFFDCF3E6) : const Color(0xFFFBF0D6),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                done ? '✔ تم السداد بالكامل' : 'نسبة السداد ${(pct * 100).round()}%',
                style: t(12.8, w: FontWeight.w800, color: done ? const Color(0xFF157A46) : const Color(0xFF8A6212)),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: btn('📄 حفظ التقرير PDF', exportPdf, kind: 'alt')),
          const SizedBox(width: 8),
          Expanded(child: btn('📤 مشاركة', share, kind: 'alt')),
        ]),
        const SizedBox(height: 8),
        btn('🗑️ تفريغ كل البيانات', () async {
          if (await confirm('⚠️ سيتم مسح جميع المشتريات والدفعات نهائياً. هل أنت متأكد؟')) {
            tx = [];
            pays = [];
            _persist();
            setState(_fixSel);
            toast('تم تفريغ البيانات', err: true);
          }
        }, kind: 'danger'),
      ]),
    );
  }

  Widget _sumRow(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(a, style: t(14.9)),
          Text(b, style: t(14.9)),
        ]),
      );

  Widget _payBox(String n, double rem) {
    final v = numP(payAmt.text);
    final ok = v != null && v > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [P.paid.withOpacity(.09), Colors.transparent]),
        border: Border.all(color: P.paid.withOpacity(.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('💵 دفع جزء من المبلغ', style: t(16.3, w: FontWeight.w800, color: P.paid)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: c.card, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12)),
          child: Text.rich(
            TextSpan(style: t(14, h: 1.9), children: [
              const TextSpan(text: 'المتبقي الحالي على '),
              TextSpan(text: n, style: t(14, w: FontWeight.w800)),
              const TextSpan(text: ': '),
              TextSpan(text: fmt(rem), style: t(14, w: FontWeight.w800, color: P.owe)),
              if (ok) ...[
                TextSpan(text: '\nبعد دفع ${fmt(v)} يصبح المتبقي: '),
                TextSpan(text: fmt((rem - v) < 0 ? 0 : rem - v), style: t(14, w: FontWeight.w800, color: P.paid)),
                if (v > rem + 0.001) TextSpan(text: ' (المبلغ أكبر من المتبقي)', style: t(14, color: P.owe)),
              ],
            ]),
          ),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: labeled('المبلغ المدفوع', field(payAmt, hint: '0.00', kb: const TextInputType.numberWithOptions(decimal: true)))),
          const SizedBox(width: 10),
          Expanded(child: labeled('ملاحظة (اختياري)', field(payNote, hint: 'دفعة نقدية...'))),
        ]),
        Row(children: [
          Expanded(
              child: btn('✔ تسجيل الدفعة', () {
            addPayment(numP(payAmt.text), payNote.text.trim());
            payAmt.clear();
            payNote.clear();
            FocusScope.of(context).unfocus();
          }, kind: 'pay')),
          const SizedBox(width: 8),
          Expanded(
              child: btn('سداد المتبقي بالكامل', () async {
            if (rem > 0 && await confirm('تسجيل سداد كامل بمبلغ ${fmt(rem)}؟')) {
              addPayment(rem, 'سداد كامل');
            }
          }, kind: 'alt')),
        ]),
      ]),
    );
  }
}
