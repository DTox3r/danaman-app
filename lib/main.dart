import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:html/parser.dart' show parse;
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  runApp(JodedormanApp(prefs: prefs)); // Nombre interno ASCII
}

class JodedormanApp extends StatefulWidget {
  final SharedPreferences prefs;
  const JodedormanApp({super.key, required this.prefs});
  @override
  State<JodedormanApp> createState() => _JodedormanAppState();
}

class _JodedormanAppState extends State<JodedormanApp> {
  ThemeMode _themeMode = ThemeMode.system;
  void toggleTheme() => setState(() => _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dañaman', // Aquí sí podemos usar la Ñ porque es un String
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.orange, brightness: Brightness.dark),
      themeMode: _themeMode,
      home: MainNavigation(onThemeToggle: toggleTheme, prefs: widget.prefs),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final SharedPreferences prefs;
  const MainNavigation({super.key, required this.onThemeToggle, required this.prefs});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<String> historial = [];
  @override
  void initState() {
    super.initState();
    historial = widget.prefs.getStringList('historial_v4_2_5') ?? [];
  }
  void _updateHistorial(List<String> nuevo) {
    setState(() => historial = nuevo);
    widget.prefs.setStringList('historial_v4_2_5', nuevo);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(onThemeToggle: widget.onThemeToggle, onHistorialUpdate: _updateHistorial, prefs: widget.prefs),
          HistoryScreen(historial: historial),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Calculadora'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final Function(List<String>) onHistorialUpdate;
  final SharedPreferences prefs;
  const HomeScreen({super.key, required this.onThemeToggle, required this.onHistorialUpdate, required this.prefs});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double bcvDolar = 0.0, bcvEuro = 0.0, binanceCompra = 0.0, binanceVenta = 0.0;
  String infoTasa = "Cargando...";
  bool isLoading = true, canRefresh = true, esTasaFutura = false, modoCompra = true;
  final TextEditingController _controller = TextEditingController();
  double resultado = 0.0;
  String monedaSeleccionada = "USD BCV";
  List<String> localHistorial = [];

  @override
  void initState() { 
    super.initState(); 
    localHistorial = widget.prefs.getStringList('historial_v4_2_5') ?? [];
    actualizarDatos(); 
  }

  Future<void> _guardarEnHistorial() async {
    String f = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String h = DateFormat('hh:mm:ss a').format(DateTime.now());
    if (binanceCompra > 0) {
      localHistorial.insert(0, "Binance Compra|$binanceCompra|$f|$h");
      localHistorial.insert(1, "Binance Venta|$binanceVenta|$f|$h");
    }
    if (!esTasaFutura && bcvDolar > 0) {
      localHistorial.insert(2, "BCV Dolar|$bcvDolar|$f|$h");
      localHistorial.insert(3, "BCV Euro|$bcvEuro|$f|$h");
    }
    if (localHistorial.length > 8000) localHistorial = localHistorial.sublist(0, 8000);
    widget.onHistorialUpdate(localHistorial);
  }

  double _buscarUltimoValido(String prefijo, String fecha) {
    try {
      if (fecha.isNotEmpty) {
        String registro = localHistorial.firstWhere((e) => e.startsWith(prefijo) && e.contains(fecha));
        return double.parse(registro.split('|')[1]);
      }
      String registroGenerico = localHistorial.firstWhere((e) => e.startsWith(prefijo));
      return double.parse(registroGenerico.split('|')[1]);
    } catch (e) { return 0.0; }
  }

  Future<void> actualizarDatos() async {
    if (!mounted || !canRefresh) return;
    setState(() { isLoading = true; canRefresh = false; });
    try {
      binanceCompra = await _fetchBinance("BUY");
      binanceVenta = await _fetchBinance("SELL");

      final resWeb = await http.get(Uri.parse('https://www.bcv.org.ve/')).timeout(const Duration(seconds: 12));
      if (resWeb.statusCode == 200) {
        var doc = parse(resWeb.body);
        var usdT = doc.getElementById('dolar')?.querySelector('strong')?.text.trim();
        var eurT = doc.getElementById('euro')?.querySelector('strong')?.text.trim();
        var fechaT = doc.querySelector('.date-display-single')?.text.trim() ?? "";
        
        if (usdT != null && eurT != null) {
          double usdWeb = double.parse(usdT.replaceAll(',', '.'));
          double eurWeb = double.parse(eurT.replaceAll(',', '.'));
          
          DateTime ahora = DateTime.now();
          String hoyStr = DateFormat('dd/MM/yyyy').format(ahora);
          bool esFechaCorrecta = fechaT.contains(ahora.day.toString()) || fechaT.contains(ahora.day.toString().padLeft(2, '0'));
          
          if (usdWeb > 20.0) {
            if (!esFechaCorrecta) {
              esTasaFutura = true;
              double backupDolar = _buscarUltimoValido("BCV Dolar", hoyStr);
              bcvDolar = (backupDolar > 0) ? backupDolar : usdWeb;
              double backupEuro = _buscarUltimoValido("BCV Euro", hoyStr);
              bcvEuro = (backupEuro > 0) ? backupEuro : eurWeb;
              infoTasa = "Tasas BCV de $hoyStr vigentes";
            } else { 
              bcvDolar = usdWeb; 
              bcvEuro = eurWeb; 
              infoTasa = "Tasas BCV: $fechaT"; 
              esTasaFutura = false; 
            }
            await _guardarEnHistorial();
          }
        }
      }
    } catch (e) { 
      bcvDolar = _buscarUltimoValido("BCV Dolar", "");
      bcvEuro = _buscarUltimoValido("BCV Euro", "");
      binanceCompra = 0.0; 
      binanceVenta = 0.0;
      infoTasa = "Modo Offline - Tasas BCV rescatadas"; 
    }
    
    if (mounted) setState(() => isLoading = false);
    _ejecutarCalculo(_controller.text);
    Future.delayed(const Duration(seconds: 10), () { if (mounted) setState(() => canRefresh = true); });
  }

  Future<double> _fetchBinance(String type) async {
    try {
      final res = await http.post(Uri.parse('https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"asset": "USDT", "fiat": "VES", "tradeType": type, "rows": 1, "page": 1, "publisherType": "merchant"}),
      );
      return double.parse(jsonDecode(res.body)['data'][0]['adv']['price'].toString());
    } catch (e) { return 0.0; }
  }

  void _ejecutarCalculo(String v) {
    double m = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    double t = (monedaSeleccionada.contains("USD")) ? bcvDolar : (monedaSeleccionada.contains("EUR")) ? bcvEuro : (monedaSeleccionada.contains("COMPRA")) ? binanceCompra : binanceVenta;
    setState(() => resultado = t > 0 ? (modoCompra ? m * t : m / t) : 0.0);
  }

  String _generarPlantilla() {
    String moneda = monedaSeleccionada.split(' ')[0];
    double t = (monedaSeleccionada.contains("USD")) ? bcvDolar : (monedaSeleccionada.contains("EUR")) ? bcvEuro : (monedaSeleccionada.contains("COMPRA")) ? binanceCompra : binanceVenta;
    String f = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String h = DateFormat('hh:mm a').format(DateTime.now());
    return "📊 *Dañaman - Reporte*\n📅 $f | $h\n🔹 *Monto:* ${_controller.text} ${modoCompra ? moneda : 'Bs'}\n🔹 *Tasa:* ${t.toStringAsFixed(2)} ($monedaSeleccionada)\n✅ *Total: ${resultado.toStringAsFixed(2)} ${modoCompra ? 'Bs' : moneda}*\n---";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color txtCol = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text("Dañaman v4.5.8 Pro"), actions: [
        IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.onThemeToggle),
        IconButton(icon: Icon(Icons.refresh, color: canRefresh ? null : Colors.grey), onPressed: canRefresh ? actualizarDatos : null),
      ]),
      body: RefreshIndicator(
        onRefresh: actualizarDatos,
        child: isLoading ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: Column(children: [
            if (esTasaFutura) _buildBanner(),
            _buildMonitores(),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(infoTasa, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold))),
            const Divider(),
            _buildCalculadora(txtCol),
          ]),
        ),
      ),
    );
  }

  Widget _buildMonitores() {
    return Column(children: [
      Row(children: [ _card("USD BCV", bcvDolar, Colors.blue), const SizedBox(width: 8), _card("EUR BCV", bcvEuro, Colors.purple) ]),
      const SizedBox(height: 8),
      Row(children: [ _card("BINANCE COMPRA", binanceCompra, Colors.orange), const SizedBox(width: 8), _card("BINANCE VENTA", binanceVenta, Colors.deepOrange) ]),
    ]);
  }

  Widget _card(String t, double p, Color c) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: c.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withOpacity(0.1))),
      child: Column(children: [
        Text(t, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)),
        Text(p == 0 ? "---" : p.toStringAsFixed(2), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    ));
  }

  Widget _buildCalculadora(Color txtCol) {
    return Column(children: [
      DropdownButtonFormField<String>(
        value: monedaSeleccionada,
        isDense: true,
        style: TextStyle(fontSize: 14, color: txtCol, fontWeight: FontWeight.bold),
        items: ["USD BCV", "EUR BCV", "Binance COMPRA", "Binance VENTA"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { setState(() => monedaSeleccionada = v!); _ejecutarCalculo(_controller.text); },
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(), labelText: "Indicador"),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(modoCompra ? "Divisas" : "Bs", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          IconButton(onPressed: () { setState(() { modoCompra = !modoCompra; _ejecutarCalculo(_controller.text); }); }, icon: const Icon(Icons.swap_horiz, size: 30, color: Colors.orange)),
          Text(modoCompra ? "Bs" : "Divisas", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      ),
      TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 18, color: txtCol, fontWeight: FontWeight.bold),
        decoration: InputDecoration(labelText: modoCompra ? "Cantidad en Divisas" : "Cantidad en Bolívares", border: const OutlineInputBorder()),
        onChanged: _ejecutarCalculo,
      ),
      const SizedBox(height: 12),
      _buildCuadroResultado(),
    ]);
  }

  Widget _buildCuadroResultado() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withOpacity(0.3))),
      child: Column(children: [
        Text(modoCompra ? "TOTAL BS" : "TOTAL DIVISAS", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(resultado.toStringAsFixed(2), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(width: 15),
          IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () {
            Clipboard.setData(ClipboardData(text: _generarPlantilla())).then((_) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plantilla copiada"), duration: Duration(seconds: 1)));
            });
          }),
          IconButton(icon: const Icon(Icons.share, size: 20, color: Colors.green), onPressed: () { Share.share(_generarPlantilla()); }),
        ]),
      ]),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.5))),
      child: const Text("⚠️ Tasa futura detectada en BCV.\nUsando último valor vigente guardado.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final List<String> historial;
  const HistoryScreen({super.key, required this.historial});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historial Dañaman"), actions: [
        IconButton(icon: const Icon(Icons.file_download), onPressed: () => _exportarCSV(historial)),
      ]),
      body: historial.isEmpty ? const Center(child: Text("Sin registros")) : ListView(
        padding: const EdgeInsets.all(10),
        children: [_buildFolder("BCV Dolar", Colors.blue), _buildFolder("BCV Euro", Colors.purple), _buildFolder("Binance Compra", Colors.orange), _buildFolder("Binance Venta", Colors.deepOrange)],
      ),
    );
  }
  Widget _buildFolder(String cat, Color col) {
    List<String> filtrado = historial.where((e) => e.startsWith(cat)).toList();
    double min = 0.0, max = 0.0;
    if (filtrado.isNotEmpty) {
      List<double> val = filtrado.map((e) => double.tryParse(e.split('|')[1]) ?? 0.0).toList();
      min = val.reduce((c, n) => c < n ? c : n); max = val.reduce((c, n) => c > n ? c : n);
    }
    return Card(elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(color: col.withOpacity(0.2)), borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(leading: Icon(Icons.folder, color: col), title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text("${filtrado.length} registros"),
        children: [
          if (filtrado.isNotEmpty) Container(padding: const EdgeInsets.all(8), color: col.withOpacity(0.05), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_extremoText("MÍNIMO", min, Colors.green), _extremoText("MÁXIMO", max, Colors.red)])),
          ...filtrado.map((i) { var p = i.split('|'); return ListTile(dense: true, title: Text(p[1], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${p[2]} - ${p[3]}")); }),
        ],
      ),
    );
  }
  Widget _extremoText(String l, double v, Color c) => Column(children: [Text(l, style: TextStyle(fontSize: 9, color: c)), Text(v.toStringAsFixed(2), style: TextStyle(fontSize: 16, color: c))]);
  Future<void> _exportarCSV(List<String> h) async {
    String csv = "Indicador,Tasa,Fecha,Hora\n" + h.map((e) => e.replaceAll('|', ',')).join('\n');
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/historial_tasas.csv");
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Exportación Dañaman');
  }
}