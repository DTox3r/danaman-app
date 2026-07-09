# Proyecto Danaman App


## Archivo: pubspec.yaml

```yaml
name: convertidor_bcv
description: "A new Flutter project."
# The following line prevents the package from being accidentally published to
# pub.dev using `flutter pub publish`. This is preferred for private packages.
publish_to: 'none' # Remove this line if you wish to publish to pub.dev

# The following defines the version and build number for your application.
# A version number is three numbers separated by dots, like 1.2.43
# followed by an optional build number separated by a +.
# Both the version and the builder number may be overridden in flutter
# build by specifying --build-name and --build-number, respectively.
# In Android, build-name is used as versionName while build-number used as versionCode.
# Read more about Android versioning at https://developer.android.com/studio/publish/versioning
# In iOS, build-name is used as CFBundleShortVersionString while build-number is used as CFBundleVersion.
# Read more about iOS versioning at
# https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
# In Windows, build-name is used as the major, minor, and patch parts
# of the product and file versions while build-number is used as the build suffix.
version: 4.5.9+1

environment:
  sdk: ^3.11.3

# Dependencies specify other packages that your package needs in order to work.
# To automatically upgrade your package dependencies to the latest versions
# consider running `flutter pub upgrade --major-versions`. Alternatively,
# dependencies can be manually updated by changing the version numbers below to
# the latest version available on pub.dev. To see which dependencies have newer
# versions available, run `flutter pub outdated`.
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.2
  html: ^0.15.4
  share_plus: ^7.2.1
  intl: ^0.19.0
  path_provider: ^2.1.1
  
  # The following adds the Cupertino Icons font to your application.
  # Use with the CupertinoIcons class for iOS style icons.
  cupertino_icons: ^1.0.8
  file_picker: ^11.0.2

dev_dependencies:
  flutter_test:
    sdk: flutter

  # The "flutter_lints" package below contains a set of recommended lints to
  # encourage good coding practices. The lint set provided by the package is
  # activated in the `analysis_options.yaml` file located at the root of your
  # package. See that file for information about deactivating specific lint
  # rules and activating additional ones.
  flutter_lints: ^6.0.0

# For information on the generic Dart part of this file, see the
# following page: https://dart.dev/tools/pub/pubspec

# The following section is specific to Flutter packages.
flutter:

  # The following line ensures that the Material Icons font is
  # included with your application, so that you can use the icons in
  # the material Icons class.
  uses-material-design: true

  # To add assets to your application, add an assets section, like this:
  # assets:
  #   - images/a_dot_burr.jpeg
  #   - images/a_dot_ham.jpeg

  # An image asset can refer to one or more resolution-specific "variants", see
  # https://flutter.dev/to/resolution-aware-images

  # For details regarding adding assets from package dependencies, see
  # https://flutter.dev/to/asset-from-package

  # To add custom fonts to your application, add a fonts section here,
  # in this "flutter" section. Each entry in this list should have a
  # "family" key with the font family name, and a "fonts" key with a
  # list giving the asset and other descriptors for the font. For
  # example:
  # fonts:
  #   - family: Schyler
  #     fonts:
  #       - asset: fonts/Schyler-Regular.ttf
  #       - asset: fonts/Schyler-Italic.ttf
  #         style: italic
  #   - family: Trajan Pro
  #     fonts:
  #       - asset: fonts/TrajanPro.ttf
  #       - asset: fonts/TrajanPro_Bold.ttf
  #         weight: 700
  #
  # For details regarding fonts from package dependencies,
  # see https://flutter.dev/to/font-from-package
```


## Archivo: lib\main.dart

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/storage_service.dart';
import 'screens/main_navigation.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final StorageService storageService = StorageService(prefs);
  runApp(JodedormanApp(storage: storageService));
}

class JodedormanApp extends StatefulWidget {
  final StorageService storage;
  const JodedormanApp({super.key, required this.storage});
  @override
  State<JodedormanApp> createState() => _JodedormanAppState();
}

class _JodedormanAppState extends State<JodedormanApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(
      () => _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dañaman',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: MainNavigation(onThemeToggle: toggleTheme, storage: widget.storage),
    );
  }
}
```


## Archivo: lib\screens\history_screen.dart

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatelessWidget {
  final List<String> historial;
  final Function(List<String>) onHistorialUpdate;
  final StorageService storage;
  
  const HistoryScreen({
    super.key, 
    required this.historial,
    required this.onHistorialUpdate,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historial Dañaman"), actions: [
        IconButton(icon: const Icon(Icons.file_upload), onPressed: () => _importarCSV(context)),
        IconButton(icon: const Icon(Icons.file_download), onPressed: () => _exportarCSV(historial)),
      ]),
      body: historial.isEmpty ? const Center(child: Text("Sin registros")) : ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _buildFolder("BCV Dolar", Colors.blue), 
          _buildFolder("BCV Euro", Colors.purple), 
          _buildFolder("Binance Compra", Colors.orange), 
          _buildFolder("Binance Venta", Colors.deepOrange)
        ],
      ),
    );
  }

  Widget _buildFolder(String cat, Color col) {
    List<String> filtrado = historial.where((e) => e.startsWith(cat)).toList();
    double min = 0.0, max = 0.0;
    if (filtrado.isNotEmpty) {
      List<double> val = filtrado.map((e) => double.tryParse(e.split('|')[1]) ?? 0.0).toList();
      min = val.reduce((c, n) => c < n ? c : n); 
      max = val.reduce((c, n) => c > n ? c : n);
    }
    return Card(elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(color: col.withAlpha(51)), borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(leading: Icon(Icons.folder, color: col), title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text("${filtrado.length} registros"),
        children: [
          if (filtrado.isNotEmpty) Container(padding: const EdgeInsets.all(8), color: col.withAlpha(13), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_extremoText("MÍNIMO", min, Colors.green), _extremoText("MÁXIMO", max, Colors.red)])),
          ...filtrado.map((i) { var p = i.split('|'); return ListTile(dense: true, title: Text(p[1], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${p[2]} - ${p[3]}")); }).toList(),
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

  Future<void> _importarCSV(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();
        List<String> lines = contents.split('\n');
        
        if (lines.isNotEmpty && lines[0].startsWith('Indicador')) {
          lines.removeAt(0); // Remover cabecera
        }
        
        List<String> nuevosRegistros = [];
        for (String line in lines) {
          if (line.trim().isEmpty) continue;
          List<String> parts = line.split(',');
          if (parts.length >= 4) {
            String ind = parts[0];
            String tas = parts[1];
            String fec = parts[2];
            String hor = parts.sublist(3).join(','); // Por si la hora tiene comas
            nuevosRegistros.add("$ind|$tas|$fec|$hor");
          }
        }
        
        if (nuevosRegistros.isNotEmpty) {
          List<String> merged = await storage.mergeHistorial(nuevosRegistros);
          onHistorialUpdate(merged);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Historial importado con éxito")));
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El archivo no contiene registros válidos")));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al importar historial")));
      }
    }
  }
}
```


## Archivo: lib\screens\home_screen.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final Function(List<String>) onHistorialUpdate;
  final StorageService storage;
  const HomeScreen({super.key, required this.onThemeToggle, required this.onHistorialUpdate, required this.storage});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  double bcvDolar = 0.0, bcvEuro = 0.0, binanceCompra = 0.0, binanceVenta = 0.0;
  String infoTasa = "Cargando...";
  bool isLoading = true, canRefresh = true, esTasaFutura = false, modoCompra = true;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _tasaManualController = TextEditingController();
  double resultado = 0.0;
  String monedaSeleccionada = "USD BCV";
  
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  @override
  void initState() { 
    super.initState(); 
    _controller.addListener(() {
      setState(() {}); // Forzar reconstrucción para mostrar/ocultar el botón (X)
    });
    actualizarDatos(); 
  }
  
  @override
  void dispose() {
    _controller.dispose();
    _tasaManualController.dispose();
    super.dispose();
  }

  Future<void> actualizarDatos() async {
    if (!mounted || !canRefresh) return;
    setState(() { isLoading = true; canRefresh = false; });
    
    ApiResult res = await _apiService.fetchAllRates(widget.storage);
    
    bcvDolar = res.bcvDolar;
    bcvEuro = res.bcvEuro;
    binanceCompra = res.binanceCompra;
    binanceVenta = res.binanceVenta;
    infoTasa = res.infoTasa;
    esTasaFutura = res.esTasaFutura;
    
    if (!res.offlineMode) {
      List<String> nuevoHistorial = await widget.storage.guardarTasasEnHistorial(
        binanceCompra: binanceCompra,
        binanceVenta: binanceVenta,
        bcvDolar: bcvDolar,
        bcvEuro: bcvEuro,
        esTasaFutura: esTasaFutura,
      );
      widget.onHistorialUpdate(nuevoHistorial);
    }
    
    if (mounted) setState(() => isLoading = false);
    HapticFeedback.mediumImpact();
    _ejecutarCalculo(_controller.text);
    Future.delayed(const Duration(seconds: 10), () { if (mounted) setState(() => canRefresh = true); });
  }

  void _ejecutarCalculo(String v) {
    double m = double.tryParse(v.replaceAll(',', '.')) ?? 0.0;
    double t = 0.0;
    if (monedaSeleccionada == "Tasa Manual") {
      t = double.tryParse(_tasaManualController.text.replaceAll(',', '.')) ?? 0.0;
    } else {
      t = (monedaSeleccionada.contains("USD")) ? bcvDolar : (monedaSeleccionada.contains("EUR")) ? bcvEuro : (monedaSeleccionada.contains("COMPRA")) ? binanceCompra : binanceVenta;
    }
    setState(() => resultado = t > 0 ? (modoCompra ? m * t : m / t) : 0.0);
  }

  String _generarPlantilla() {
    String moneda = (monedaSeleccionada == "Tasa Manual") ? "Divisa" : monedaSeleccionada.split(' ')[0];
    double t = 0.0;
    if (monedaSeleccionada == "Tasa Manual") {
      t = double.tryParse(_tasaManualController.text.replaceAll(',', '.')) ?? 0.0;
    } else {
      t = (monedaSeleccionada.contains("USD")) ? bcvDolar : (monedaSeleccionada.contains("EUR")) ? bcvEuro : (monedaSeleccionada.contains("COMPRA")) ? binanceCompra : binanceVenta;
    }
    String f = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String h = DateFormat('hh:mm a').format(DateTime.now());
    return "📊 *Dañaman - Reporte*\n📅 $f | $h\n🔹 *Monto:* ${_currencyFormat.format(double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0.0)} ${modoCompra ? moneda : 'Bs'}\n🔹 *Tasa:* ${_currencyFormat.format(t)} ($monedaSeleccionada)\n✅ *Total: ${_currencyFormat.format(resultado)} ${modoCompra ? 'Bs' : moneda}*\n---";
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color txtCol = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text("Dañaman v4.5.9 Pro"), actions: [
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
      decoration: BoxDecoration(color: c.withAlpha(13), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withAlpha(26))),
      child: Column(children: [
        Text(t, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)),
        Text(p == 0 ? "---" : _currencyFormat.format(p), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    ));
  }

  Widget _buildCalculadora(Color txtCol) {
    return Column(children: [
      DropdownButtonFormField<String>(
        value: monedaSeleccionada, // DropdownMenuItem value still uses value, DropdownButtonFormField in older versions uses initialValue but value works too, ignoring warning.
        isDense: true,
        style: TextStyle(fontSize: 14, color: txtCol, fontWeight: FontWeight.bold),
        items: ["USD BCV", "EUR BCV", "Binance COMPRA", "Binance VENTA", "Tasa Manual"].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) { 
          HapticFeedback.selectionClick();
          setState(() => monedaSeleccionada = v!); 
          _ejecutarCalculo(_controller.text); 
        },
        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8), border: OutlineInputBorder(), labelText: "Indicador"),
      ),
      if (monedaSeleccionada == "Tasa Manual")
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: TextField(
            controller: _tasaManualController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(fontSize: 14, color: txtCol, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(),
              labelText: "Ingrese Tasa Manual (Bs)",
            ),
            onChanged: (v) => _ejecutarCalculo(_controller.text),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(modoCompra ? "Divisas" : "Bs", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          IconButton(onPressed: () { 
            HapticFeedback.lightImpact();
            setState(() { modoCompra = !modoCompra; _ejecutarCalculo(_controller.text); }); 
          }, icon: const Icon(Icons.swap_horiz, size: 30, color: Colors.orange)),
          Text(modoCompra ? "Bs" : "Divisas", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        ]),
      ),
      TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(fontSize: 18, color: txtCol, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: modoCompra ? "Cantidad en Divisas" : "Cantidad en Bolívares", 
          border: const OutlineInputBorder(),
          suffixIcon: _controller.text.isNotEmpty ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              _ejecutarCalculo('');
            },
          ) : null,
        ),
        onChanged: _ejecutarCalculo,
      ),
      const SizedBox(height: 12),
      _buildCuadroResultado(),
    ]);
  }

  Widget _buildCuadroResultado() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.orange.withAlpha(13), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange.withAlpha(77))),
      child: Column(children: [
        Text(modoCompra ? "TOTAL BS" : "TOTAL DIVISAS", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange)),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: Text(
              _currencyFormat.format(resultado), 
              key: ValueKey<double>(resultado),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.orange)
            ),
          ),
          const SizedBox(width: 15),
          IconButton(icon: const Icon(Icons.copy, size: 20), onPressed: () {
            HapticFeedback.lightImpact();
            Clipboard.setData(ClipboardData(text: _generarPlantilla())).then((_) {
              if (!mounted) return;
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
      decoration: BoxDecoration(color: Colors.red.withAlpha(26), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withAlpha(128))),
      child: const Text("⚠️ Tasa futura detectada en BCV.\nUsando último valor vigente guardado.", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}
```


## Archivo: lib\screens\main_navigation.dart

```dart
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'history_screen.dart';

class MainNavigation extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final StorageService storage;

  const MainNavigation({super.key, required this.onThemeToggle, required this.storage});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<String> historial = [];

  @override
  void initState() {
    super.initState();
    historial = widget.storage.getHistorial();
  }

  void _updateHistorial(List<String> nuevo) {
    setState(() => historial = nuevo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            onThemeToggle: widget.onThemeToggle, 
            onHistorialUpdate: _updateHistorial, 
            storage: widget.storage
          ),
          HistoryScreen(
            historial: historial,
            onHistorialUpdate: _updateHistorial,
            storage: widget.storage,
          ),
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
```


## Archivo: lib\services\api_service.dart

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';
import 'storage_service.dart';

class ApiResult {
  final double binanceCompra;
  final double binanceVenta;
  final double bcvDolar;
  final double bcvEuro;
  final String infoTasa;
  final bool esTasaFutura;
  final bool offlineMode;

  ApiResult({
    required this.binanceCompra,
    required this.binanceVenta,
    required this.bcvDolar,
    required this.bcvEuro,
    required this.infoTasa,
    required this.esTasaFutura,
    this.offlineMode = false,
  });
}

class ApiService {
  static const List<String> _meses = [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ];

  Future<ApiResult> fetchAllRates(StorageService storage) async {
    double binanceCompra = 0.0;
    double binanceVenta = 0.0;
    double bcvDolar = 0.0;
    double bcvEuro = 0.0;
    String infoTasa = "Cargando...";
    bool esTasaFutura = false;
    bool offlineMode = false;

    try {
      binanceCompra = await _fetchBinance("BUY");
      binanceVenta = await _fetchBinance("SELL");

      DateTime ahora = DateTime.now();
      String hoyStr = DateFormat('dd/MM/yyyy').format(ahora);
      List<String> hist = storage.getHistorial();
      
      double savedDolar = storage.buscarUltimoValido("BCV Dolar", hoyStr, hist);
      double savedEuro = storage.buscarUltimoValido("BCV Euro", hoyStr, hist);

      if (savedDolar > 0 && savedEuro > 0) {
        bcvDolar = savedDolar;
        bcvEuro = savedEuro;
        infoTasa = "Tasas BCV de hoy ($hoyStr)";
        esTasaFutura = false;
      } else {
        final resWeb = await http.get(Uri.parse('https://www.bcv.org.ve/')).timeout(const Duration(seconds: 12));
        if (resWeb.statusCode == 200) {
          var doc = parse(resWeb.body);
          var usdT = doc.getElementById('dolar')?.querySelector('strong')?.text.trim();
          var eurT = doc.getElementById('euro')?.querySelector('strong')?.text.trim();
          var fechaT = doc.querySelector('.date-display-single')?.text.trim() ?? "";
          
          if (usdT != null && eurT != null) {
            double usdWeb = double.parse(usdT.replaceAll(',', '.'));
            double eurWeb = double.parse(eurT.replaceAll(',', '.'));
            
            // Lógica anti-futuro mejorada: comprueba día y mes.
            String diaActual = ahora.day.toString();
            String diaActual0 = diaActual.padLeft(2, '0');
            String mesActual = _meses[ahora.month - 1]; // Mes en español
            String mesNum = ahora.month.toString().padLeft(2, '0');
            
            bool tieneDia = fechaT.contains(diaActual) || fechaT.contains(diaActual0);
            bool tieneMes = fechaT.toLowerCase().contains(mesActual.toLowerCase()) || 
                            fechaT.contains("/$mesNum") || 
                            fechaT.contains("-$mesNum");
            
            bool esFechaCorrecta = tieneDia && tieneMes;
            
            if (usdWeb > 20.0) {
              if (!esFechaCorrecta) {
                esTasaFutura = true;
                double backupDolar = storage.buscarUltimoValido("BCV Dolar", hoyStr, hist);
                bcvDolar = (backupDolar > 0) ? backupDolar : usdWeb;
                double backupEuro = storage.buscarUltimoValido("BCV Euro", hoyStr, hist);
                bcvEuro = (backupEuro > 0) ? backupEuro : eurWeb;
                infoTasa = "Tasas BCV de $hoyStr vigentes";
              } else { 
                bcvDolar = usdWeb; 
                bcvEuro = eurWeb; 
                infoTasa = "Tasas BCV: $fechaT"; 
                esTasaFutura = false; 
              }
            }
          }
        }
      }
    } catch (e) { 
      List<String> hist = storage.getHistorial();
      bcvDolar = storage.buscarUltimoValido("BCV Dolar", "", hist);
      bcvEuro = storage.buscarUltimoValido("BCV Euro", "", hist);
      binanceCompra = 0.0; 
      binanceVenta = 0.0;
      infoTasa = "Modo Offline - Tasas BCV rescatadas"; 
      offlineMode = true;
    }
    
    return ApiResult(
      binanceCompra: binanceCompra,
      binanceVenta: binanceVenta,
      bcvDolar: bcvDolar,
      bcvEuro: bcvEuro,
      infoTasa: infoTasa,
      esTasaFutura: esTasaFutura,
      offlineMode: offlineMode,
    );
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
}
```


## Archivo: lib\services\storage_service.dart

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class StorageService {
  final SharedPreferences prefs;
  static const String _historialKey = 'historial_v4_2_5';

  StorageService(this.prefs);

  List<String> getHistorial() {
    return prefs.getStringList(_historialKey) ?? [];
  }

  Future<void> updateHistorial(List<String> nuevo) async {
    await prefs.setStringList(_historialKey, nuevo);
  }

  Future<List<String>> guardarTasasEnHistorial({
    required double binanceCompra,
    required double binanceVenta,
    required double bcvDolar,
    required double bcvEuro,
    required bool esTasaFutura,
  }) async {
    List<String> localHistorial = getHistorial();
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
    if (localHistorial.length > 8000) {
      localHistorial = localHistorial.sublist(0, 8000);
    }
    
    await updateHistorial(localHistorial);
    return localHistorial;
  }
  
  double buscarUltimoValido(String prefijo, String fecha, List<String> historial) {
    try {
      if (fecha.isNotEmpty) {
        String registro = historial.firstWhere((e) => e.startsWith(prefijo) && e.contains(fecha));
        return double.parse(registro.split('|')[1]);
      }
      String registroGenerico = historial.firstWhere((e) => e.startsWith(prefijo));
      return double.parse(registroGenerico.split('|')[1]);
    } catch (e) { 
      return 0.0; 
    }
  }

  Future<List<String>> mergeHistorial(List<String> importados) async {
    List<String> localHistorial = getHistorial();
    Set<String> existentes = localHistorial.toSet();
    
    for (String imp in importados) {
      if (!existentes.contains(imp)) {
        localHistorial.add(imp);
        existentes.add(imp);
      }
    }
    
    // Ordenar de más reciente a más antiguo
    localHistorial.sort((a, b) {
      try {
        var pa = a.split('|');
        var pb = b.split('|');
        DateTime da = DateFormat('dd/MM/yyyy hh:mm:ss a').parse("${pa[2]} ${pa[3]}");
        DateTime db = DateFormat('dd/MM/yyyy hh:mm:ss a').parse("${pb[2]} ${pb[3]}");
        return db.compareTo(da);
      } catch (e) {
        return 0; // Si falla el parseo, mantener orden relativo
      }
    });

    if (localHistorial.length > 8000) {
      localHistorial = localHistorial.sublist(0, 8000);
    }
    
    await updateHistorial(localHistorial);
    return localHistorial;
  }
}
```


## Archivo: android\app\src\main\AndroidManifest.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <application
        android:label="Jodedorman v4.5.8"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true"> <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme" />
            
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>
        
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```


