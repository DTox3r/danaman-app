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
  String futureTasaInfo = "";
  bool isLoading = true, canRefresh = true, esTasaFutura = false, modoCompra = true;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _tasaManualController = TextEditingController();
  
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
    futureTasaInfo = res.futureTasaInfo;
    
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
    
    if (mounted) {
      setState(() => isLoading = false);
      if (res.offlineMode) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Error de conexión. Mostrando tasas guardadas en caché.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ));
      }
    }
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(seconds: 10), () { if (mounted) setState(() => canRefresh = true); });
  }

  String _generarPlantillaUnica(String nombre, double tasa, double calc, double monto) {
    String f = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String h = DateFormat('hh:mm a').format(DateTime.now());
    String moneda = "Divisa"; 
    if (nombre.contains("EUR")) moneda = "EUR";
    else if (nombre.contains("USD") || nombre.contains("BINANCE")) moneda = "USD";
    return "📊 *Convertidor Pro - Reporte*\n📅 $f | $h\n🔹 *Monto:* ${_currencyFormat.format(monto)} ${modoCompra ? moneda : 'Bs'}\n🔹 *Tasa:* ${_currencyFormat.format(tasa)} ($nombre)\n✅ *Total: ${_currencyFormat.format(calc)} ${modoCompra ? 'Bs' : moneda}*\n---";
  }

  void _copiarUnico(String nombre, double tasa, double calc, double monto) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _generarPlantillaUnica(nombre, tasa, calc, monto))).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Plantilla copiada"), duration: Duration(seconds: 1)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color txtCol = isDark ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(title: const Text("Convertidor Pro de Tasas Version 4.6"), actions: [
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
    double monto = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0.0;
    double tasaManual = double.tryParse(_tasaManualController.text.replaceAll(',', '.')) ?? 0.0;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: _tasaManualController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 14, color: txtCol, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(),
            labelText: "Tasa Manual Opcional (Bs)",
          ),
          onChanged: (v) => setState(() {}),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(modoCompra ? "Divisas" : "Bs", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          IconButton(onPressed: () { 
            HapticFeedback.lightImpact();
            setState(() { modoCompra = !modoCompra; }); 
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
          prefixIcon: const Icon(Icons.calculate_outlined),
          suffixIcon: _controller.text.isNotEmpty ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _controller.clear();
              setState(() {});
            },
          ) : null,
        ),
        onChanged: (v) => setState(() {}),
      ),
      const SizedBox(height: 15),
      
      // Resultados Universales
      _resultCard("USD BCV", bcvDolar, monto, Colors.blue),
      _resultCard("EUR BCV", bcvEuro, monto, Colors.purple),
      _resultCard("BINANCE VENTA", binanceVenta, monto, Colors.deepOrange),
      _resultCard("BINANCE COMPRA", binanceCompra, monto, Colors.orange),
      if (tasaManual > 0) _resultCard("TASA MANUAL", tasaManual, monto, Colors.teal),
    ]);
  }

  Widget _resultCard(String nombre, double tasa, double monto, Color color) {
    if (tasa == 0.0) return const SizedBox(); 
    double calc = modoCompra ? (monto * tasa) : (monto / tasa);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withAlpha(15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withAlpha(50))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _currencyFormat.format(calc), 
                    key: ValueKey<double>(calc),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)
                  ),
                ),
              ],
            ),
          ),
          IconButton(icon: Icon(Icons.copy, size: 20, color: color), onPressed: () => _copiarUnico(nombre, tasa, calc, monto)),
          IconButton(icon: Icon(Icons.share, size: 20, color: color), onPressed: () => Share.share(_generarPlantillaUnica(nombre, tasa, calc, monto))),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.blue.withAlpha(26), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withAlpha(128))),
      child: Text(futureTasaInfo.isNotEmpty ? futureTasaInfo : "Tasa futura detectada", textAlign: TextAlign.center, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}
