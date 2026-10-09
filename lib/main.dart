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

  final String htmlContent = '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>دائن - إدارة الديون</title>
<style>
:root{
  --bg:#eaf0ee; --card:#fff; --ink:#12302f; --muted:#6a8280; --line:#dbe6e3;
  --brand:#0d6b5e; --brand2:#12907d; --deep:#0a2e2c; --gold:#e3a72f;
  --owe:#c2492f; --paid:#1f9d5c; --soft:#eaf5f2; --r:18px;
}
:root[data-theme="dark"]{--bg:#0b1716;--card:#12211f;--ink:#e6f0ee;--muted:#8fa8a4;--line:#223936;--soft:#17302d;color-scheme:dark}
*{box-sizing:border-box;margin:0;padding:0;font-family:Tahoma,Arial,sans-serif}
body{background:var(--bg);color:var(--ink);padding-bottom:90px;line-height:1.5;padding:14px}
.app{max-width:720px;margin:0 auto}
header{background:var(--brand);color:#fff;padding:20px;border-radius:16px;text-align:center;position:relative;margin-bottom:15px}
.theme{position:absolute;top:10px;left:10px;padding:8px 12px;border-radius:8px;border:0;background:rgba(255,255,255,0.2);color:#fff;cursor:pointer}
.card{background:var(--card);border:1px solid var(--line);border-radius:var(--r);padding:18px;margin-bottom:16px}
label{display:block;font-size:0.8rem;font-weight:700;color:var(--muted);margin-bottom:6px}
input,select{width:100%;padding:12px;border:1.5px solid var(--line);border-radius:12px;font-size:0.96rem;background:var(--bg);color:var(--ink);margin-bottom:10px;outline:none}
.btn{width:100%;padding:13px;border:0;border-radius:13px;font-weight:800;color:#fff;background:var(--brand);cursor:pointer;margin-top:5px}
.btn.alt{background:var(--muted)}
table{width:100%;border-collapse:collapse;font-size:0.85rem;margin-top:10px}
th,td{padding:10px;text-align:center;border-bottom:1px solid var(--line)}
th{background:var(--soft);color:var(--muted)}
</style>
</head>
<body>
<div class="app">
  <header>
    <button class="theme" id="themeBtn">🌙</button>
    <h1>دائن</h1>
    <p>إدارة الديون والمشتريات بكل سهولة</p>
  </header>

  <div class="card">
    <h2>📝 تسجيل مشتريات</h2>
    <form id="buyForm">
      <label>اسم الدائن</label>
      <input id="dName" placeholder="اكتب اسم الدائن هنا..." autocomplete="off">
      
      <label>المنتج</label>
      <input id="pName" placeholder="سكر، شاي، زيت...">
      
      <label>السعر</label>
      <input id="pPrice" type="number" step="any" placeholder="0.00">

      <label>شهر الشراء</label>
      <select id="pMonth"></select>

      <button class="btn">➕ إضافة للدائن</button>
    </form>
  </div>

  <div class="card">
    <h2>👤 كشف الحساب</h2>
    <label>اختر الدائن</label>
    <select id="sel"></select>

    <table>
      <thead>
        <tr><th>الشهر</th><th>المنتج</th><th>السعر</th></tr>
      </thead>
      <tbody id="buyBody">
        <tr><td colspan="3">لا توجد بيانات</td></tr>
      </tbody>
    </table>

    <button class="btn alt" id="btnPdf" style="margin-top:15px">📄 تصدير تقرير PDF</button>
  </div>
</div>

<script>
const MONTHS=["يناير","فبراير","مارس","أبريل","مايو","يونيو","يوليو","أغسطس","سبتمبر","أكتوبر","نوفمبر","ديسمبر"];
const g = id => document.getElementById(id);
MONTHS.forEach(m => g('pMonth').add(new Option(m,m)));

let theme = localStorage.getItem('theme') || 'light';
function setTheme(t) {
  theme = t;
  document.documentElement.setAttribute('data-theme', t);
  g('themeBtn').textContent = t === 'dark' ? '☀️' : '🌙';
  localStorage.setItem('theme', t);
}
g('themeBtn').onclick = () => setTheme(theme === 'dark' ? 'light' : 'dark');
setTheme(theme);

let tx = JSON.parse(localStorage.getItem('tx') || '[]');

function refresh() {
  const names = [...new Set(tx.map(t => t.name))];
  g('sel').innerHTML = names.length ? names.map(n => `<option value="\${n}">\${n}</option>`).join('') : '<option value="">لا يوجد دائنون</option>';
  
  const cur = g('sel').value;
  const items = tx.filter(t => t.name === cur);
  g('buyBody').innerHTML = items.length ? items.map(t => `<tr><td>\${t.month}</td><td>\${t.product}</td><td>\${t.price}</td></tr>`).join('') : '<tr><td colspan="3">لا توجد مشتريات</td></tr>';
}

g('buyForm').onsubmit = e => {
  e.preventDefault();
  const name = g('dName').value.trim();
  const product = g('pName').value.trim();
  const price = g('pPrice').value;
  const month = g('pMonth').value;

  if(!name || !product || !price) return alert('الرجاء تعبئة كافة الحقول');

  tx.push({name, product, price, month});
  localStorage.setItem('tx', JSON.stringify(tx));
  g('pName').value = '';
  g('pPrice').value = '';
  refresh();
  alert('تم الحفظ بنجاح');
};

g('sel').onchange = refresh;

g('btnPdf').onclick = () => {
  const cur = g('sel').value;
  if(!cur) return alert('اختر دائناً أولاً');
  if(window.pdfChannel) {
    window.pdfChannel.postMessage(cur);
  }
};

refresh();
</script>
</body>
</html>
''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFEAF0EE))
      ..addJavaScriptChannel(
        'pdfChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _generateAndSharePdf(message.message);
        },
      )
      ..loadHtmlString(htmlContent);
  }

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
                    style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Text('تم استخراج هذا التقرير عبر تطبيق دائن لإدارة الديون.'),
              ],
            ),
          );
        },
      ),
    );
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
