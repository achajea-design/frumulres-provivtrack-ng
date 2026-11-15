import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ShopDb.instance.init();
  runApp(const ProviTrackApp());
}

final money = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 2);
final dateFmt = DateFormat('dd MMM yyyy, hh:mm a');

class ShopDb {
  ShopDb._();
  static final instance = ShopDb._();
  Database? _db;
  Database get db => _db!;

  Future<void> init() async {
    final path = p.join(await getDatabasesPath(), 'frumulres_provitrack_ng.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, version) async {
      await db.execute('''CREATE TABLE products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL, quantity REAL NOT NULL DEFAULT 0,
        cost REAL NOT NULL DEFAULT 0, price REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE sales(
        id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER,
        product_name TEXT NOT NULL, quantity REAL NOT NULL,
        unit_price REAL NOT NULL, total REAL NOT NULL,
        payment_method TEXT NOT NULL, created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE expenses(
        id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT NOT NULL,
        amount REAL NOT NULL, note TEXT, created_at TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE settings(
        key TEXT PRIMARY KEY, value TEXT NOT NULL)''');
      await db.insert('settings', {'key':'starting_capital','value':'430650'});
    });
  }

  Future<double> capital() async {
    final rows = await db.query('settings', where: 'key=?', whereArgs: ['starting_capital']);
    return rows.isEmpty ? 430650 : double.tryParse(rows.first['value'].toString()) ?? 430650;
  }

  Future<List<Map<String,dynamic>>> products() => db.query('products', orderBy: 'name COLLATE NOCASE');
  Future<List<Map<String,dynamic>>> sales() => db.query('sales', orderBy: 'id DESC');
  Future<List<Map<String,dynamic>>> expenses() => db.query('expenses', orderBy: 'id DESC');

  Future<void> addProduct(String name, double qty, double cost, double price) async {
    await db.insert('products', {'name':name.trim(),'quantity':qty,'cost':cost,'price':price,'created_at':DateTime.now().toIso8601String()});
  }

  Future<void> updateProduct(Map<String,dynamic> product) async {
    await db.update('products', product, where: 'id=?', whereArgs: [product['id']]);
  }

  Future<void> recordSale(int productId, String name, double qty, double price, String method) async {
    await db.transaction((txn) async {
      final rows = await txn.query('products', where: 'id=?', whereArgs: [productId]);
      if (rows.isEmpty) throw Exception('Product not found.');
      final available = (rows.first['quantity'] as num).toDouble();
      if (qty <= 0 || qty > available) throw Exception('Quantity exceeds available stock.');
      await txn.update('products', {'quantity': available - qty}, where: 'id=?', whereArgs: [productId]);
      await txn.insert('sales', {
        'product_id':productId,'product_name':name,'quantity':qty,
        'unit_price':price,'total':qty*price,'payment_method':method,
        'created_at':DateTime.now().toIso8601String()
      });
    });
  }

  Future<void> addExpense(String title, double amount, String note) async {
    await db.insert('expenses', {'title':title.trim(),'amount':amount,'note':note.trim(),'created_at':DateTime.now().toIso8601String()});
  }

  Future<Map<String,double>> totals() async {
    final ps = await db.query('products');
    final ss = await db.query('sales');
    final es = await db.query('expenses');
    double stockCost = 0, stockRetail = 0, revenue = 0, cogs = 0, expenseTotal = 0;
    for (final x in ps) {
      final q=(x['quantity'] as num).toDouble();
      stockCost += q*(x['cost'] as num).toDouble();
      stockRetail += q*(x['price'] as num).toDouble();
    }
    for (final x in ss) {
      final q=(x['quantity'] as num).toDouble();
      revenue += (x['total'] as num).toDouble();
      final productId=x['product_id'];
      final matches=ps.where((v)=>v['id']==productId);
      if (matches.isNotEmpty) cogs += q*(matches.first['cost'] as num).toDouble();
    }
    for (final x in es) { expenseTotal += (x['amount'] as num).toDouble(); }
    return {'revenue':revenue,'expenses':expenseTotal,'cogs':cogs,
      'grossProfit':revenue-cogs,'netProfit':revenue-cogs-expenseTotal,
      'stockCost':stockCost,'stockRetail':stockRetail,
      'products':ps.length.toDouble(),'salesCount':ss.length.toDouble()};
  }
}

class ProviTrackApp extends StatelessWidget {
  const ProviTrackApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Frumulres ProviTrack NG',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b50)), useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState()=>_HomePageState();
}
class _HomePageState extends State<HomePage> {
  int tab=0;
  void refresh()=>setState((){});
  @override
  Widget build(BuildContext context) {
    final pages=[Dashboard(onChanged:refresh), ProductsPage(onChanged:refresh), SalesPage(onChanged:refresh), ExpensesPage(onChanged:refresh), ReportsPage()];
    return Scaffold(
      appBar: AppBar(title: const Text('Frumulres ProviTrack NG'), centerTitle: false),
      body: pages[tab],
      bottomNavigationBar: NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations: const [
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Home'),
        NavigationDestination(icon:Icon(Icons.inventory_2_outlined),label:'Stock'),
        NavigationDestination(icon:Icon(Icons.point_of_sale),label:'Sales'),
        NavigationDestination(icon:Icon(Icons.receipt_long),label:'Expenses'),
        NavigationDestination(icon:Icon(Icons.bar_chart),label:'Reports'),
      ]),
    );
  }
}

class Dashboard extends StatelessWidget {
  final VoidCallback onChanged;
  const Dashboard({super.key,required this.onChanged});
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,double>>(
    future:ShopDb.instance.totals(),builder:(context,s){
      if(!s.hasData)return const Center(child:CircularProgressIndicator());
      final t=s.data!;
      return ListView(padding:const EdgeInsets.all(16),children:[
        Card(color:Theme.of(context).colorScheme.primaryContainer,child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('Starting capital',style:TextStyle(fontSize:14)),
          FutureBuilder<double>(future:ShopDb.instance.capital(),builder:(c,v)=>Text(money.format(v.data??430650),style:const TextStyle(fontSize:26,fontWeight:FontWeight.bold))),
          const SizedBox(height:4),const Text('Configured business opening capital'),
        ]))),
        const SizedBox(height:8),
        GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,childAspectRatio:1.55,crossAxisSpacing:10,mainAxisSpacing:10,children:[
          metric('Sales revenue',money.format(t['revenue']),'payments'),
          metric('Expenses',money.format(t['expenses']),'receipt'),
          metric('Net profit',money.format(t['netProfit']),'trending_up'),
          metric('Stock at cost',money.format(t['stockCost']),'inventory'),
        ]),
        const SizedBox(height:12),
        Card(child:ListTile(leading:const Icon(Icons.inventory),title:const Text('Products recorded'),trailing:Text('${t['products']!.toInt()}'))),
        Card(child:ListTile(leading:const Icon(Icons.point_of_sale),title:const Text('Sales transactions'),trailing:Text('${t['salesCount']!.toInt()}'))),
        const Padding(padding:EdgeInsets.only(top:12),child:Text('Net profit = sales revenue − cost of goods sold − recorded expenses.',style:TextStyle(color:Colors.grey))),
      ]);
    });
  Widget metric(String title,String value,String icon)=>Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Icon(icon=='payments'?Icons.payments:icon=='receipt'?Icons.receipt:icon=='inventory'?Icons.inventory:Icons.trending_up,color:Colors.teal),Text(title,style:const TextStyle(fontSize:12)),FittedBox(child:Text(value,style:const TextStyle(fontSize:16,fontWeight:FontWeight.bold)))])));
}

class ProductsPage extends StatefulWidget { final VoidCallback onChanged; const ProductsPage({super.key,required this.onChanged}); @override State<ProductsPage> createState()=>_ProductsPageState(); }
class _ProductsPageState extends State<ProductsPage>{
  Future<void> add() async {
    final name=TextEditingController(),qty=TextEditingController(),cost=TextEditingController(),price=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Add product'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      field(name,'Product name'),field(qty,'Opening quantity',numeric:true),field(cost,'Unit cost (₦)',numeric:true),field(price,'Selling price (₦)',numeric:true),
    ])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save'))]));
    if(ok==true&&name.text.trim().isNotEmpty){
      final q=double.tryParse(qty.text)??0,co=double.tryParse(cost.text)??0,pr=double.tryParse(price.text)??0;
      if(q>=0&&co>=0&&pr>=0){await ShopDb.instance.addProduct(name.text,q,co,pr);widget.onChanged();setState((){});}
    }
  }
  @override Widget build(BuildContext context)=>Scaffold(floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add product')),body:FutureBuilder<List<Map<String,dynamic>>>(future:ShopDb.instance.products(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    if(s.data!.isEmpty)return const Center(child:Text('No products yet. Tap Add product to enter shop stock.'));
    return ListView.builder(itemCount:s.data!.length,itemBuilder:(c,i){final x=s.data![i];return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(title:Text(x['name']),subtitle:Text('Qty: ${x['quantity']}  •  Cost: ${money.format(x['cost'])}'),trailing:Text(money.format(x['price']),style:const TextStyle(fontWeight:FontWeight.bold))));});
  }));
}

class SalesPage extends StatefulWidget {final VoidCallback onChanged;const SalesPage({super.key,required this.onChanged});@override State<SalesPage> createState()=>_SalesPageState();}
class _SalesPageState extends State<SalesPage>{
  Future<void> sell() async {
    final products=await ShopDb.instance.products();
    if(!mounted)return;
    if(products.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Add products before recording a sale.')));return;}
    int selected=products.first['id'] as int; final qty=TextEditingController(text:'1');String method='Cash';
    final ok=await showDialog<bool>(context:context,builder:(c)=>StatefulBuilder(builder:(c,refresh)=>AlertDialog(title:const Text('Record sale'),content:Column(mainAxisSize:MainAxisSize.min,children:[
      DropdownButtonFormField<int>(value:selected,decoration:const InputDecoration(labelText:'Product'),items:products.map((x)=>DropdownMenuItem(value:x['id'] as int,child:Text('${x['name']} (${x['quantity']} available)'))).toList(),onChanged:(v)=>refresh(()=>selected=v!)),
      field(qty,'Quantity',numeric:true),
      DropdownButtonFormField<String>(value:method,decoration:const InputDecoration(labelText:'Payment'),items:const [DropdownMenuItem(value:'Cash',child:Text('Cash')),DropdownMenuItem(value:'Transfer',child:Text('Transfer')),DropdownMenuItem(value:'POS',child:Text('POS'))],onChanged:(v)=>refresh(()=>method=v!)),
    ]),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save sale'))])));
    if(ok==true){final product=products.firstWhere((x)=>x['id']==selected);try{await ShopDb.instance.recordSale(selected,product['name'],double.parse(qty.text), (product['price'] as num).toDouble(),method);widget.onChanged();setState((){});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString().replaceFirst('Exception: ',''))));}}
  }
  @override Widget build(BuildContext context)=>Scaffold(floatingActionButton:FloatingActionButton.extended(onPressed:sell,icon:const Icon(Icons.add_shopping_cart),label:const Text('Record sale')),body:FutureBuilder<List<Map<String,dynamic>>>(future:ShopDb.instance.sales(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    if(s.data!.isEmpty)return const Center(child:Text('No sales recorded yet.'));
    return ListView(children:s.data!.map((x)=>Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(title:Text(x['product_name']),subtitle:Text('${x['quantity']} × ${money.format(x['unit_price'])} • ${x['payment_method']}'),trailing:Text(money.format(x['total'])))).toList());
  }));
}

class ExpensesPage extends StatefulWidget {final VoidCallback onChanged;const ExpensesPage({super.key,required this.onChanged});@override State<ExpensesPage> createState()=>_ExpensesPageState();}
class _ExpensesPageState extends State<ExpensesPage>{
  Future<void> add() async {
    final title=TextEditingController(),amount=TextEditingController(),note=TextEditingController();
    final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Record expense'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[field(title,'Expense description'),field(amount,'Amount (₦)',numeric:true),field(note,'Note (optional)')])),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Save expense'))]));
    final value=double.tryParse(amount.text);
    if(ok==true&&title.text.trim().isNotEmpty&&value!=null&&value>0){await ShopDb.instance.addExpense(title.text,value,note.text);widget.onChanged();setState((){});}
  }
  @override Widget build(BuildContext context)=>Scaffold(floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('Add expense')),body:FutureBuilder<List<Map<String,dynamic>>>(future:ShopDb.instance.expenses(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    if(s.data!.isEmpty)return const Center(child:Text('No expenses recorded yet.'));
    return ListView(children:s.data!.map((x)=>Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:5),child:ListTile(title:Text(x['title']),subtitle:Text(dateFmt.format(DateTime.parse(x['created_at']))),trailing:Text(money.format(x['amount']),style:const TextStyle(fontWeight:FontWeight.bold)))).toList());
  }));
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override Widget build(BuildContext context)=>FutureBuilder<Map<String,double>>(future:ShopDb.instance.totals(),builder:(c,s){
    if(!s.hasData)return const Center(child:CircularProgressIndicator());
    final t=s.data!;
    final rows={'Total sales revenue':t['revenue']!,'Cost of goods sold':t['cogs']!,'Gross profit':t['grossProfit']!,'Operating expenses':t['expenses']!,'Net profit':t['netProfit']!,'Remaining stock at cost':t['stockCost']!,'Remaining stock at selling value':t['stockRetail']!};
    return ListView(padding:const EdgeInsets.all(16),children:[Text('Business summary',style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),...rows.entries.map((e)=>Card(child:ListTile(title:Text(e.key),trailing:Text(money.format(e.value),style:const TextStyle(fontWeight:FontWeight.bold))))),const Padding(padding:EdgeInsets.only(top:12),child:Text('Figures are calculated from transactions entered into this app. Review product costs and quantities for accurate reports.',style:TextStyle(color:Colors.grey)))]);
  });
}

Widget field(TextEditingController c,String label,{bool numeric=false})=>Padding(padding:const EdgeInsets.only(bottom:10),child:TextField(controller:c,keyboardType:numeric?const TextInputType.numberWithOptions(decimal:true):TextInputType.text,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder())));
