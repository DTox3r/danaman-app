import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';

class P2pEstimatorScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onThemeToggle;

  const P2pEstimatorScreen({super.key, required this.storage, required this.onThemeToggle});

  @override
  State<P2pEstimatorScreen> createState() => _P2pEstimatorScreenState();
}

class _P2pEstimatorScreenState extends State<P2pEstimatorScreen> {
  final TextEditingController _usdtController = TextEditingController();
  final TextEditingController _feeController = TextEditingController(text: "0.06");
  
  String operacion = "COMPRAR USDT";
  double tasaBase = 0.0;
  double resultadoBs = 0.0;
  double tasaNeta = 0.0;

  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'es_VE', symbol: '', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    _cargarTasaBase();
  }

  @override
  void dispose() {
    _usdtController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  void _cargarTasaBase() {
    List<String> hist = widget.storage.getHistorial();
    if (operacion == "COMPRAR USDT") {
      tasaBase = widget.storage.buscarUltimoValido("Binance Venta", "", hist);
    } else {
      tasaBase = widget.storage.buscarUltimoValido("Binance Compra", "", hist);
    }
    _calcular();
  }

  void _calcular() {
    double usdt = double.tryParse(_usdtController.text.replaceAll(',', '.')) ?? 0.0;
    double feeUSDT = double.tryParse(_feeController.text.replaceAll(',', '.')) ?? 0.0;
    
    // Según las capturas de Binance:
    // Al COMPRAR: Pagas por (USDT deseado + comisión)
    // Al VENDER: Recibes bolívares por (USDT vendido - comisión)
    
    double usdtTotal = 0.0;
    
    if (operacion == "COMPRAR USDT") {
      usdtTotal = usdt > 0 ? usdt + feeUSDT : 0.0;
      tasaNeta = tasaBase; // La tasa no cambia, cambia la cantidad de USDT
    } else {
      usdtTotal = usdt > 0 ? usdt - feeUSDT : 0.0;
      if (usdtTotal < 0) usdtTotal = 0.0;
      tasaNeta = tasaBase;
    }
    
    setState(() {
      resultadoBs = usdtTotal * tasaBase;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color txtCol = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Estimador P2P Binance"),
        actions: [
          IconButton(icon: const Icon(Icons.brightness_6), onPressed: widget.onThemeToggle),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            HapticFeedback.mediumImpact();
            _cargarTasaBase();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tasa base recargada desde el historial"), duration: Duration(seconds: 1)));
          }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown para operación
            DropdownButtonFormField<String>(
              value: operacion,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Operación en Binance",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "COMPRAR USDT", child: Text("COMPRAR USDT (Tasa Venta)", overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: "VENDER USDT", child: Text("VENDER USDT (Tasa Compra)", overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) {
                if (v != null) {
                  HapticFeedback.selectionClick();
                  setState(() => operacion = v);
                  _cargarTasaBase();
                }
              },
            ),
            const SizedBox(height: 15),
            
            // Tasa Base Actual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.withAlpha(50))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Tasa Base Actual:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(tasaBase > 0 ? _currencyFormat.format(tasaBase) : "---", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ],
              ),
            ),
            const SizedBox(height: 15),

            // Campos de texto
            TextField(
              controller: _feeController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: txtCol, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: "Comisión de Binance (USDT)",
                helperText: "Ejemplo: 0.06 se sumará a tus USDT a pagar.",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on_outlined),
              ),
              onChanged: (_) => _calcular(),
            ),
            const SizedBox(height: 15),

            TextField(
              controller: _usdtController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(fontSize: 18, color: txtCol, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: "Cantidad de USDT",
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.monetization_on, color: Colors.green),
                suffixIcon: _usdtController.text.isNotEmpty ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _usdtController.clear();
                    _calcular();
                  },
                ) : null,
              ),
              onChanged: (_) => _calcular(),
            ),
            const SizedBox(height: 25),

            // Resultado Final
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.green.withAlpha(80))
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Tasa Neta Aplicada:", style: TextStyle(fontSize: 14)),
                      Text(_currencyFormat.format(tasaNeta), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(),
                  Text("TOTAL ESTIMADO EN BS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _currencyFormat.format(resultadoBs),
                      key: ValueKey<double>(resultadoBs),
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
