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

  // كود الـ HTML الأصلي كاملاً مع تعديل زر الـ PDF ليتواصل مع فلاتر
  final String htmlContent = '''
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link href="https://fonts.googleapis.com/css2?family=Tajawal:wght@400;500;700;800&display=swap" rel="stylesheet">
<title>دائن - إدارة الديون</title>
<style>
:root{
  --bg:#eaf0ee; --card:#fff; --ink:#12302f; --muted:#6a8280; --line:#dbe6e3;
  --brand:#0d6b5e; --brand2:#12907d; --deep:#0a2e2c; --gold:#e3a72f;
  --owe:#c2492f; --paid:#1f9d5c; --soft:#eaf5f2; --r:18px;
  --sh:0 1px 2px rgba(10,46,44,.06),0 8px 24px -10px rgba(10,46,44,.18);
}
:root[data-theme="dark"]{--bg:#0b1716;--card:#12211f;--ink:#e6f0ee;--muted:#8fa8a4;--line:#223936;--soft:#17302d;--sh:0 8px 24px -10px rgba(0,0,0,.6);color-scheme:dark}
*{box-sizing:border-box;margin:0;padding:0;font-family:'Tajawal','Segoe UI',Tahoma,Arial,sans-serif}
body{background:var(--bg);color:var(--ink);padding-bottom:90px;line-height:1.5}
.app{max-width:720px;margin:0 auto;padding:0 14px}
header{background:linear-gradient(145deg,var(--deep),var(--brand));color:#fff;margin:0 -14px 0;padding:26px 22px 70px;border-radius:0 0 28px 28px;position:relative;overflow:hidden}
header::after{content:"";position:absolute;left:-40px;top:-50px;width:190px;height:190px;border-radius:50%;background:rgba(227,167,47,.18)}
header::before{content:"";position:absolute;left:60px;bottom:-70px;width:150px;height:150px;border-radius:50%;background:rgba(255,255,255,.07)}
.theme{position:absolute;top:16px;left:16px;z-index:3;width:44px;height:44px;border-radius:14px;border:1px solid rgba(255,255,255,.25);background:rgba(255,255,255,.12);color:#fff;font-size:1.3rem;cursor:pointer;display:grid;place-items:center;backdrop-filter:blur(4px);transition:.2s}
.theme:hover{background:rgba(255,255,255,.22);transform:rotate(15deg)}
.brand{display:flex;align-items:center;gap:14px;position:relative;z-index:1}
.logo{width:50px;height:50px;border-radius:15px;background:var(--gold);color:var(--deep);display:grid;place-items:center;font-size:1.6rem;box-shadow:0 6px 14px rgba(0,0,0,.25)}
header h1{font-size:1.5rem;font-weight:800}
header p{font-size:.85rem;opacity:.8;margin-top:1px}
.stats{display:grid;grid-template-columns:repeat(2,1fr);gap:10px;margin:-48px 0 16px;position:relative;z-index:2}
.stat{background:var(--card);border-radius:16px;padding:13px 14px;box-shadow:var(--sh);display:flex;align-items:center;gap:11px;border:1px solid var(--line)}
.stat .ic{width:40px;height:40px;border-radius:12px;display:grid;place-items:center;font-size:1.2rem;background:var(--soft);flex:none}
.stat.owe .ic{background:#fbe6e0}.stat.paid .ic{background:#dcf3e6}.stat.gold .ic{background:#fbf0d6}
.stat small{display:block;font-size:.74rem;color:var(--muted);font-weight:500}
.stat b{font-size:1.15rem;font-weight:800}
.stat.owe b{color:var(--owe)}.stat.paid b{color:var(--paid)}
.card{background:var(--card);border:1px solid var(--line);border-radius:var(--r);padding:18px;margin-bottom:16px;box-shadow:var(--sh)}
.card h2{font-size:1.02rem;font-weight:800;margin-bottom:14px;padding-bottom:10px;border-bottom:1px dashed var(--line)}
label{display:block;font-size:.8rem;font-weight:700;color:var(--muted);margin-bottom:6px}
input,select{width:100%;padding:12px 14px;border:1.5px solid var(--line);border-radius:12px;font-size:.96rem;background:var(--bg);color:var(--ink);outline:none;transition:.18s}
input:focus,select:focus{border-color:var(--brand2);background:var(--card);box-shadow:0 0 0 4px rgba(18,144,125,.16)}
.fg{margin-bottom:12px}.row{display:flex;gap:10px}.row .fg{flex:1;min-width:0}
.btn{width:100%;padding:13px;border:0;border-radius:13px;font-weight:800;font-size:.96rem;cursor:pointer;color:#fff;background:linear-gradient(135deg,var(--brand),var(--brand2));box-shadow:0 8px 16px -8px rgba(13,107,94,.7);transition:.18s}
.btn:hover{filter:brightness(1.08);transform:translateY(-1px)}.btn:active{transform:scale(.98)}
.btn.pay{background:linear-gradient(135deg,#198a50,#27b36d);box-shadow:0 8px 16px -8px rgba(31,157,92,.7)}
.btn.alt{background:var(--soft);color:var(--brand2);box-shadow:none;border:1px solid var(--line)}
.btn.danger{background:transparent;color:var(--owe);box-shadow:none;border:1px solid rgba(194,73,47,.35)}
.btns{display:flex;gap:8px;margin-top:10px}.btns .btn{flex:1}
.pick{background:var(--soft);padding:13px;border-radius:14px;margin-bottom:16px;border:1px solid var(--line)}
#payBox{background:linear-gradient(180deg,rgba(31,157,92,.09),transparent);border:1px solid rgba(31,157,92,.25);border-radius:14px;padding:14px;margin-bottom:16px}
#payBox h2{border:0;padding:0;margin-bottom:10px;color:var(--paid)}
.payinfo{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:10px 14px;margin-bottom:12px;font-size:.88rem;line-height:1.9}.payinfo b{font-weight:800}.payinfo .a{color:var(--owe)}.payinfo .b{color:var(--paid)}
.tw{overflow-x:auto;border:1px solid var(--line);border-radius:14px;margin-top:8px}
table{width:100%;border-collapse:collapse;font-size:.85rem}
th,td{padding:10px 11px;text-align:center;white-space:nowrap}
th{background:var(--soft);color:var(--muted);font-weight:700;font-size:.78rem}
tbody tr:nth-child(even){background:rgba(18,144,125,.04)}
tbody td{border-top:1px solid var(--line)}
.sub{font-size:.92rem;font-weight:800;margin-top:16px}
.del{background:none;border:0;cursor:pointer;font-size:1rem;padding:4px 8px;border-radius:8px;opacity:.7}
.del:hover{background:#fbe6e0;opacity:1}
.sum{margin-top:14px;border-radius:16px;overflow:hidden;border:1px solid var(--line)}
.sum div{display:flex;justify-content:space-between;padding:11px 16px;font-size:.93rem}
.sum div+div{border-top:1px solid var(--line)}
.sum .rem{background:linear-gradient(135deg,var(--deep),var(--brand));color:#fff;font-weight:800;font-size:1.1rem;padding:15px 16px}
.sum .rem span:last-child{color:#ffd37a}.sum .rem.zero span:last-child{color:#8df0b4}
.bar{height:10px;background:var(--line);border-radius:10px;margin-top:14px;overflow:hidden}
.bar i{display:block;height:100%;width:0;background:linear-gradient(90deg,var(--paid),#6fdc9f);border-radius:10px;transition:width .5s}
.badge{display:inline-block;margin-top:10px;padding:5px 16px;border-radius:30px;font-size:.8rem;font-weight:800}
.badge.ok{background:#dcf3e6;color:#157a46}.badge.no{background:#fbf0d6;color:#8a6212}
.empty{color:var(--muted);padding:22px!important;text-align:center}
#pdfArea{background:var(--card);padding:6px 2px}
#pdfArea h3{text-align:center;font-size:1.08rem;font-weight:800;margin-bottom:4px}
#toast{position:fixed;bottom:22px;left:50%;transform:translate(-50%,120px);background:var(--deep);color:#fff;padding:12px 24px;border-radius:30px;font-weight:700;font-size:.9rem;transition:transform .3s;z-index:9;box-shadow:0 10px 24px rgba(0,0,0,.3);border-bottom:3px solid var(--paid)}
#toast.show{transform:translate(-50%,0)}#toast.err{border-bottom-color:var(--owe)}
:focus-visible{outline:2px solid var(--gold);outline-offset:2px}
@media(min-width:640px){.stats{grid-template-columns:repeat(4,1fr)}.stat{flex-direction:column;text-align:center;gap:6px}}
@media print{
  body{background:#fff;color:#000}.theme{display:none}body *{visibility:hidden}#pdfArea,#pdfArea *{visibility:visible}
  #pdfArea{position:absolute;inset:0 auto auto 0;width:100%}.no-print{display:none!important}
  .sum .rem{background:#eee!important;color:#000!important}.sum .rem span:last-child{color:#000!important}
}
</style>
</head>
<body>
<div class="app">
  <header><button type="button" class="theme no-print" id="themeBtn" aria-label="تبديل الوضع الفاتح/الداكن"></button><div class="brand"><div class="logo">📒</div><div><h1>دائن</h1><p>سجّل المشتريات والدفعات واعرف المتبقي على كل دائن فوراً</p></div></div></header>
  <div class="stats">
    <div class="stat gold"><span class="ic">👥</span><div><small>عدد الدائنين المسجلين</small><b id="sCount">0</b></div></div>
    <div class="stat"><span class="ic">🧾</span><div><small>إجمالي الديون</small><b id="sTotal">0.00</b></div></div>
    <div class="stat paid"><span class="ic">✅</span><div><small>المسدّد</small><b id="sPaid">0.00</b></div></div>
    <div class="stat owe"><span class="ic">⏳</span><div><small>المتبقي</small><b id="sRem">0.00</b></div></div>
  </div>
  <div class="card">
    <h2>📝 تسجيل مشتريات</h2>
    <form id="buyForm" novalidate>
      <div class="fg"><label for="dName">اسم الدائن</label>
        <input id="dName" list="dList" placeholder="اختر أو اكتب اسماً جديداً" autocomplete="off"><datalist id="dList"></datalist></div>
      <div class="fg"><label for="pName">المنتج</label><input id="pName" placeholder="سكر، شاي، زيت..."></div>
      <div class="row">
        <div class="fg"><label for="pPrice">السعر</label><input id="pPrice" type="text" inputmode="decimal" autocomplete="off" placeholder="0.00"></div>
        <div class="fg"><label for="pQty">الكمية</label><input id="pQty" type="text" inputmode="numeric" autocomplete="off" value="1"></div>
      </div>
      <div class="fg"><label for="pMonth">شهر الشراء</label><select id="pMonth"></select></div>
      <button class="btn">➕ إضافة إلى حساب الدائن</button>
    </form>
  </div>
  <div class="card">
    <h2>👤 كشف حساب الدائن</h2>
    <div class="pick"><label for="sel">اختر الدائن</label><select id="sel"></select></div>
    <div id="payBox" class="no-print">
      <h2 style="margin-top:4px">💵 دفع جزء من المبلغ</h2>
      <div class="payinfo" id="payInfo"></div>
      <form id="payForm" novalidate>
        <div class="row">
          <div class="fg"><label for="payAmt">المبلغ المدفوع</label><input id="payAmt" type="text" inputmode="decimal" autocomplete="off" placeholder="0.00"></div>
          <div class="fg"><label for="payNote">ملاحظة (اختياري)</label><input id="payNote" placeholder="دفعة نقدية..."></div>
        </div>
        <div class="btns">
          <button class="btn pay">✔ تسجيل الدفعة</button>
          <button type="button" class="btn alt" id="payAll">سداد المتبقي بالكامل</button>
        </div>
      </form>
    </div>
    <div id="pdfArea">
      <h3 id="title">كشف حساب</h3>
      <div class="sub">المشتريات</div>
      <div class="tw"><table><thead><tr><th>الشهر</th><th>المنتج</th><th>الكمية</th><th>السعر</th><th>الإجمالي</th><th class="no-print"></th></tr></thead><tbody id="buyBody"></tbody></table></div>
      <div id="payWrap"><div class="sub">الدفعات</div>
      <div class="tw"><table><thead><tr><th>التاريخ</th><th>المبلغ</th><th>ملاحظة</th><th class="no-print"></th></tr></thead><tbody id="payBody"></tbody></table></div></div>
      <div class="sum">
        <div><span>إجمالي المشتريات</span><span id="rTotal">0.00</span></div>
        <div><span>إجمالي المدفوع</span><span id="rPaid">0.00</span></div>
        <div class="rem" id="remRow"><span>المتبقي على الدائن</span><span id="rRem">0.00</span></div>
      </div>
      <div class="bar"><i id="bar"></i></div>
      <div style="text-align:center"><span class="badge no" id="badge"></span></div>
    </div>
    <div class="btns no-print">
      <button class="btn alt" id="btnPdf">📄 حفظ التقرير PDF</button>
      <button class="btn alt" id="btnShare">📤 مشاركة</button>
    </div>
    <button class="btn danger no-print" id="btnWipe" style="margin-top:8px">🗑️ تفريغ كل البيانات</button>
  </div>
</div>
<div id="toast" role="status"></div>
<script>
(function(){
'use strict';
window.addEventListener('error',e=>{try{toast('خطأ: '+e.message,1)}catch(_){}});
const MONTHS=["يناير","فبراير","مارس","أبريل","مايو","يونيو","يوليو","أغسطس","سبتمبر","أكتوبر","نوفمبر","ديسمبر"];
const g=id=>document.getElementById(id);
const num=v=>{const t=String(v).replace(/[٠-٩]/g,d=>d.charCodeAt(0)-1632).replace(/[۰-۹]/g,d=>d.charCodeAt(0)-1776).replace(/[٫,،]/g,'.').replace(/[^0-9.]/g,'');return parseFloat(t)};
const uid=()=>Date.now().toString(36)+Math.random().toString(36).slice(2,6);
const fmt=n=>(Math.round(n*100)/100).toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2});
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const load=k=>{try{return JSON.parse(localStorage.getItem(k))||[]}catch(e){return[]}};
const save=(k,v)=>{try{localStorage.setItem(k,JSON.stringify(v))}catch(e){}};
const root=document.documentElement,tb=g('themeBtn');
let theme='light';
try{theme=localStorage.getItem('theme')||(matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light')}catch(e){}
function setTheme(t){theme=t;root.setAttribute('data-theme',t);tb.textContent=t==='dark'?'☀️':'🌙';tb.title=t==='dark'?'الوضع الفاتح':'الوضع الداكن';try{localStorage.setItem('theme',t)}catch(e){}}
tb.addEventListener('click',()=>setTheme(theme==='dark'?'light':'dark'));
setTheme(theme);
let tx=load('pos_transactions').map(t=>({...t,id:t.id||uid()}));
let pays=load('pos_payments');
const persist=()=>{save('pos_transactions',tx);save('pos_payments',pays)};
MONTHS.forEach(m=>g('pMonth').add(new Option(m,m)));
g('pMonth').value=MONTHS[new Date().getMonth()];
function toast(msg,err){const t=g('toast');t.textContent=msg;t.className='show'+(err?' err':'');clearTimeout(t._h);t._h=setTimeout(()=>t.className='',2500)}
const names=()=>[...new Set([...tx,...pays].map(i=>i.name.trim()))];
const totals=n=>{
  const total=tx.filter(t=>t.name.trim()===n).reduce((s,t)=>s+t.price*t.qty,0);
  const paid=pays.filter(p=>p.name.trim()===n).reduce((s,p)=>s+p.amount,0);
  return{total,paid,rem:Math.max(0,Math.round((total-paid)*100)/100)};
};
function refresh(keep){
  const list=names(), cur=keep||g('sel').value;
  g('dList').innerHTML=list.map(n=>`<option value="${esc(n)}">`).join('');
  g('sel').innerHTML=list.length?list.map(n=>`<option value="${esc(n)}">${esc(n)}</option>`).join(''):'<option value="">لا يوجد دائنون بعد</option>';
  if(list.includes(cur))g('sel').value=cur;
  const T=tx.reduce((s,t)=>s+t.price*t.qty,0),P=pays.reduce((s,p)=>s+p.amount,0);
  g('sCount').textContent=list.length;
  g('sTotal').textContent=fmt(T);g('sPaid').textContent=fmt(P);g('sRem').textContent=fmt(list.reduce((s,n)=>s+totals(n).rem,0));
  render();
}
function payInfo(){
  const n=g('sel').value;if(!n){g('payInfo').innerHTML='';return}
  const{rem}=totals(n),v=num(g('payAmt').value),ok=v>0;
  g('payInfo').innerHTML=`المتبقي الحالي على <b>${esc(n)}</b>: <b class="a">${fmt(rem)}</b>`+(ok?`<br>بعد دفع ${fmt(v)} يصبح المتبقي: <b class="b">${fmt(Math.max(0,rem-v))}</b>`+(v>rem+0.001?' <span class="a">(المبلغ أكبر من المتبقي)</span>':''):'');
}
g('payAmt').addEventListener('input',payInfo);
function render(){
  const n=g('sel').value;
  g('payBox').style.display=n?'':'none';
  if(!n){
    g('title').textContent='كشف حساب';
    g('buyBody').innerHTML='<tr><td colspan="6" class="empty">أضف أول عملية شراء لعرض كشف الحساب</td></tr>';
    g('payWrap').style.display='none';
    ['rTotal','rPaid','rRem'].forEach(i=>g(i).textContent='0.00');
    g('bar').style.width='0';g('badge').textContent='';return;
  }
  g('title').textContent='📋 كشف حساب: '+n;
  const items=tx.filter(t=>t.name.trim()===n).sort((a,b)=>MONTHS.indexOf(a.month)-MONTHS.indexOf(b.month));
  g('buyBody').innerHTML=items.length?items.map(t=>`<tr><td><b>${esc(t.month)}</b></td><td>${esc(t.product)}</td><td>${t.qty}</td><td>${fmt(t.price)}</td><td><b>${fmt(t.price*t.qty)}</b></td><td class="no-print"><button class="del" data-t="${t.id}" aria-label="حذف">🗑️</button></td></tr>`).join(''):'<tr><td colspan="6" class="empty">لا توجد مشتريات</td></tr>';
  const ps=pays.filter(p=>p.name.trim()===n);
  g('payWrap').style.display=ps.length?'':'none';
  g('payBody').innerHTML=ps.map(p=>`<tr><td>${esc(p.date)}</td><td><b style="color:var(--paid)">${fmt(p.amount)}</b></td><td>${esc(p.note||'-')}</td><td class="no-print"><button class="del" data-p="${p.id}" aria-label="حذف">🗑️</button></td></tr>`).join('');
  const{total,paid,rem}=totals(n);
  g('rTotal').textContent=fmt(total);g('rPaid').textContent=fmt(paid);g('rRem').textContent=fmt(rem);
  g('remRow').classList.toggle('zero',rem===0);
  payInfo();
  g('bar').style.width=(total?Math.min(100,paid/total*100):0)+'%';
  const b=g('badge');b.className='badge '+(rem===0&&total>0?'ok':'no');
  b.textContent=rem===0&&total>0?'✔ تم السداد بالكامل':`نسبة السداد ${total?Math.round(paid/total*100):0}%`;
}
g('buyForm').addEventListener('submit',e=>{
  e.preventDefault();
  const name=g('dName').value.trim(),product=g('pName').value.trim(),price=num(g('pPrice').value),qty=Math.round(num(g('pQty').value));
  if(!name)return toast('اكتب اسم الدائن',1);
  if(!product)return toast('اكتب اسم المنتج',1);
  if(!(price>0))return toast('أدخل سعراً صحيحاً',1);
  if(!(qty>=1))return toast('أدخل كمية صحيحة',1);
  tx.push({id:uid(),name,product,price,qty,month:g('pMonth').value});
  persist();refresh(name);g('sel').value=name;render();
  toast('✅ تم الحفظ بنجاح');
  g('pName').value='';g('pPrice').value='';g('pQty').value='1';
});
function addPayment(amount,note){
  const n=g('sel').value,{rem}=totals(n);
  if(!(amount>0))return toast('أدخل مبلغاً صحيحاً',1);
  if(rem===0)return toast('لا يوجد مبلغ متبقٍّ على هذا الدائن',1);
  if(amount>rem+0.001)return toast(`المبلغ أكبر من المتبقي (${fmt(rem)})`,1);
  pays.push({id:uid(),name:n,amount,note,date:new Date().toLocaleDateString('en-GB')});
  if(totals(n).rem===0){
    tx=tx.filter(t=>t.name.trim()!==n);pays=pays.filter(p=>p.name.trim()!==n);
    persist();refresh();toast(`✅ تم سداد كامل المبلغ وحذف «${n}» من السجلات`);return;
  }
  persist();refresh(n);toast(`تم خصم ${fmt(amount)} — المتبقي ${fmt(totals(n).rem)}`);
}
g('payForm').addEventListener('submit',e=>{
  e.preventDefault();
  addPayment(num(g('payAmt').value),g('payNote').value.trim());
  g('payAmt').value='';g('payNote').value='';payInfo();
});
g('payAll').addEventListener('click',()=>{const r=totals(g('sel').value).rem;if(r>0&&confirm(`تسجيل سداد كامل بمبلغ ${fmt(r)}؟`))addPayment(r,'سداد كامل')});
g('sel').addEventListener('change',render);
document.addEventListener('click',e=>{
  const b=e.target.closest('.del');if(!b)return;
  if(!confirm('هل تريد حذف هذا السجل؟'))return;
  if(b.dataset.t)tx=tx.filter(t=>t.id!==b.dataset.t);
  if(b.dataset.p)pays=pays.filter(p=>p.id!==b.dataset.p);
  const n=g('sel').value;persist();refresh(n);toast('تم الحذف',1);
});
g('btnPdf').addEventListener('click',()=>{
  const n=g('sel').value;
  if(!n)return toast('لا توجد بيانات للتصدير',1);
  if(window.pdfChannel) {
    window.pdfChannel.postMessage(n);
  } else {
    window.print();
  }
});
g('btnShare').addEventListener('click',async()=>{
  const n=g('sel').value;if(!n)return toast('اختر دائناً أولاً',1);
  const{total,paid,rem}=totals(n);
  const text=`كشف حساب: ${n}\nإجمالي المشتريات: ${fmt(total)}\nالمدفوع: ${fmt(paid)}\nالمتبقي: ${fmt(rem)}`;
  try{if(navigator.share)await navigator.share({text});else{await navigator.clipboard.writeText(text);toast('تم نسخ الملخص')}}catch(e){}
});
g('btnWipe').addEventListener('click',()=>{
  if(confirm('⚠️ سيتم مسح جميع المشتريات والدفعات نهائياً. هل أنت متأكد؟')){tx=[];pays=[];persist();refresh();toast('تم تفريغ البيانات',1)}
});
refresh();
})();
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
      ..loadHtmlString(htmlContent); // تحميل الكود مباشرة كنص برمجي مضمون التشغيل
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
