import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isDark = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'دائن - إدارة الديون',
      theme: ThemeData(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primarySwatch: Colors.teal,
        fontFamily: 'Tahoma',
      ),
      home: CreditorHomeScreen(
        isDark: isDark,
        onThemeChanged: (val) => setState(() => isDark = val),
      ),
    );
  }
}

class CreditorHomeScreen extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  const CreditorHomeScreen({super.key, required this.isDark, required this.onThemeChanged});

  @override
  State<CreditorHomeScreen> createState() => _CreditorHomeScreenState();
}

class _CreditorHomeScreenState extends State<CreditorHomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String selectedMonth = 'يناير';
  String? selectedCreditor;
  List<Map<String, dynamic>> transactions = [];

  final List<String> months = [
    'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('transactions');
    if (data != null) {
      setState(() {
        transactions = List<Map<String, dynamic>>.from(json.decode(data));
      });
    }
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transactions', json.encode(transactions));
  }

  void _addTransaction() {
    final name = _nameController.text.trim();
    final product = _productController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;

    if (name.isEmpty || product.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء تعبئة جميع الحقول بشكل صحيح')),
      );
      return;
    }

    setState(() {
      transactions.add({
        'name': name,
        'product': product,
        'price': price,
        'month': selectedMonth,
      });
      selectedCreditor = name;
      _productController.clear();
      _priceController.clear();
    });

    _saveData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تمت الإضافة بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> creditors = transactions.map((e) => e['name'].toString()).toSet().toList();
    if (selectedCreditor == null && creditors.isNotEmpty) {
      selectedCreditor = creditors.first;
    }

    List<Map<String, dynamic>> currentCreditorItems = transactions
        .where((e) => e['name'] == selectedCreditor)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('دائن - إدارة الديون والمشتريات'),
          actions: [
            IconButton(
              icon: Icon(widget.isDark ? Icons.wb_sunny : Icons.nightlight_round),
              onPressed: () => widget.onThemeChanged(!widget.isDark),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // نموذج الإضافة
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('📝 تسجيل مشتريات جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'اسم الدائن', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _productController,
                        decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedMonth,
                        items: months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (val) => setState(() => selectedMonth = val!),
                        decoration: const InputDecoration(labelText: 'شهر الشراء', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 15),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
                          onPressed: _addTransaction,
                          child: const Text('➕ إضافة إلى الحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // كشف الحساب
              if (creditors.isNotEmpty) ...[
                const Text('👤 كشف حساب الدائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCreditor,
                  items: creditors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => selectedCreditor = val),
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: currentCreditorItems.length,
                  itemBuilder: (context, index) {
                    final item = currentCreditorItems[index];
                    return Card(
                      child: ListTile(
                        title: Text(item['product']),
                        subtitle: Text('الشهر: ${item['month']}'),
                        trailing: Text('${item['price']} ج.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                      ),
                    );
                  },
                ),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    textDirection: TextDirection.rtl,
                    child: Text('لا توجد بيانات مسجلة حتى الآن.', style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
