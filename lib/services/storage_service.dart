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
