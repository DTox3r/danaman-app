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

  Future<void> guardarTasaPorFecha(
    String fechaStr,
    double usd,
    double eur,
  ) async {
    if (usd > 0) await prefs.setDouble('bcv_usd_$fechaStr', usd);
    if (eur > 0) await prefs.setDouble('bcv_eur_$fechaStr', eur);
  }

  double getTasaGuardadaPorFecha(String moneda, String fechaStr) {
    final key = moneda == 'USD' ? 'bcv_usd_$fechaStr' : 'bcv_eur_$fechaStr';
    return prefs.getDouble(key) ?? 0.0;
  }

  Future<List<String>> guardarTasasEnHistorial({
    required double binanceCompra,
    required double binanceVenta,
    required double bcvDolar,
    required double bcvEuro,
    required bool esTasaFutura,
    bool guardarBcv = true,
  }) async {
    List<String> localHistorial = getHistorial();
    String f = DateFormat('dd/MM/yyyy').format(DateTime.now());
    String h = DateFormat('hh:mm:ss a').format(DateTime.now());

    final List<String> nuevos = [];
    if (binanceCompra > 0) {
      nuevos.add("Binance Compra|$binanceCompra|$f|$h");
      nuevos.add("Binance Venta|$binanceVenta|$f|$h");
    }
    if (guardarBcv && bcvDolar > 0) {
      nuevos.add("BCV Dolar|$bcvDolar|$f|$h");
      nuevos.add("BCV Euro|$bcvEuro|$f|$h");
    }
    if (nuevos.isNotEmpty) {
      localHistorial.insertAll(0, nuevos);
    }
    if (localHistorial.length > 8000) {
      localHistorial = localHistorial.sublist(0, 8000);
    }

    await updateHistorial(localHistorial);
    return localHistorial;
  }

  double buscarUltimoValido(
    String prefijo,
    String fecha,
    List<String> historial,
  ) {
    try {
      final prefijoLower = prefijo.toLowerCase().trim();
      if (fecha.isNotEmpty) {
        String registro = historial.firstWhere(
          (e) => e.toLowerCase().startsWith(prefijoLower) && e.contains(fecha),
        );
        return double.parse(registro.split('|')[1]);
      }
      String registroGenerico = historial.firstWhere(
        (e) => e.toLowerCase().startsWith(prefijoLower),
      );
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
        DateTime da = DateFormat(
          'dd/MM/yyyy hh:mm:ss a',
        ).parse("${pa[2]} ${pa[3]}");
        DateTime db = DateFormat(
          'dd/MM/yyyy hh:mm:ss a',
        ).parse("${pb[2]} ${pb[3]}");
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
