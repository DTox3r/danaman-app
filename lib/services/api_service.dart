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
  final String futureTasaInfo;

  ApiResult({
    required this.binanceCompra,
    required this.binanceVenta,
    required this.bcvDolar,
    required this.bcvEuro,
    required this.infoTasa,
    required this.esTasaFutura,
    this.offlineMode = false,
    this.futureTasaInfo = "",
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
    String futureTasaInfo = "";

    try {
      binanceCompra = await _fetchBinance("BUY");
      binanceVenta = await _fetchBinance("SELL");

      DateTime ahora = DateTime.now();
      String hoyStr = DateFormat('dd/MM/yyyy').format(ahora);
      List<String> hist = storage.getHistorial();
      
      double savedDolar = storage.buscarUltimoValido("BCV Dolar", hoyStr, hist);
      double savedEuro = storage.buscarUltimoValido("BCV Euro", hoyStr, hist);

      // Siempre intentamos buscar en la web para detectar si ya anunciaron la tasa de mañana
      try {
        final resWeb = await http.get(Uri.parse('https://www.bcv.org.ve/')).timeout(const Duration(seconds: 12));
        if (resWeb.statusCode == 200) {
          var doc = parse(resWeb.body);
          var usdT = doc.getElementById('dolar')?.querySelector('strong')?.text.trim();
          var eurT = doc.getElementById('euro')?.querySelector('strong')?.text.trim();
          var fechaT = doc.querySelector('.date-display-single')?.text.trim() ?? "";
          
          if (usdT != null && eurT != null) {
            double usdWeb = double.parse(usdT.replaceAll(',', '.'));
            double eurWeb = double.parse(eurT.replaceAll(',', '.'));
            
            if (usdWeb > 20.0) {
              // 1. Extraemos la fecha del BCV como un objeto DateTime real
              DateTime? fechaBCV = _parseBCVDate(fechaT);
              
              // 2. Comparamos matemáticamente si la fecha del BCV es del futuro
              bool esTasaFuturaReal = false;
              if (fechaBCV != null) {
                // Comparamos sin importar la hora, solo el día
                DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);
                
                // Si la fecha del BCV es estrictamente mayor a hoy, es la tasa de mañana (o el lunes)
                if (fechaBCV.isAfter(hoy)) {
                  esTasaFuturaReal = true;
                }
              }

              if (esTasaFuturaReal) {
                // Es una tasa futura. Mostrar la última conocida en los cuadros principales.
                esTasaFutura = true;
                double backupDolar = storage.buscarUltimoValido("BCV Dolar", "", hist);
                double backupEuro = storage.buscarUltimoValido("BCV Euro", "", hist);
                
                bcvDolar = (backupDolar > 0) ? backupDolar : usdWeb;
                bcvEuro = (backupEuro > 0) ? backupEuro : eurWeb;
                infoTasa = "Tasa anterior vigente en curso";
                futureTasaInfo = "¡Atención! Nueva tasa para $fechaT: ${usdWeb.toStringAsFixed(2)}";
              } else {
                bcvDolar = usdWeb; 
                bcvEuro = eurWeb; 
                infoTasa = "Tasas BCV: $fechaT"; 
                esTasaFutura = false; 
              }
            } else {
              throw Exception("Tasa BCV muy baja o inválida");
            }
          } else {
            throw Exception("No se encontraron elementos de tasa en la web");
          }
        } else {
          throw Exception("Error HTTP al consultar BCV");
        }
      } catch (e) {
        // Fallback en caso de error web (ej: timeout o caída de la página)
        if (savedDolar > 0 && savedEuro > 0) {
          bcvDolar = savedDolar;
          bcvEuro = savedEuro;
          infoTasa = "Tasas BCV de hoy ($hoyStr)";
          esTasaFutura = false;
        } else {
          bcvDolar = storage.buscarUltimoValido("BCV Dolar", "", hist);
          bcvEuro = storage.buscarUltimoValido("BCV Euro", "", hist);
          infoTasa = "Modo Offline - Tasas BCV rescatadas"; 
          offlineMode = true;
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
      futureTasaInfo: futureTasaInfo,
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

  // Nueva función matemática para transformar el texto del BCV en una Fecha Real
  DateTime? _parseBCVDate(String text) {
    try {
      text = text.toLowerCase();
      List<String> meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
      
      RegExp dayExp = RegExp(r'\b([0-3]?[0-9])\b');
      var dayMatch = dayExp.firstMatch(text);
      if (dayMatch == null) return null;
      int day = int.parse(dayMatch.group(1)!);

      int month = 0;
      for (int i = 0; i < meses.length; i++) {
        if (text.contains(meses[i])) {
          month = i + 1;
          break;
        }
      }
      if (month == 0) return null;

      RegExp yearExp = RegExp(r'\b(20[2-9][0-9])\b');
      var yearMatch = yearExp.firstMatch(text);
      int year = yearMatch != null ? int.parse(yearMatch.group(1)!) : DateTime.now().year;

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }
}
