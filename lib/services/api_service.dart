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
  /// Parsea números con formato latino (1.234,56), anglosajón (1,234.56),
  /// o simplemente con comas decimales (896,12).
  static double? parseRate(String? text) {
    if (text == null) return null;
    try {
      String clean = text.trim();
      if (clean.contains(',') && clean.contains('.')) {
        if (clean.indexOf('.') < clean.indexOf(',')) {
          // Formato latino / venezolano: 1.004,95657762 -> miles es '.', decimal es ','
          clean = clean.replaceAll('.', '').replaceAll(',', '.');
        } else {
          // Formato anglosajón: 1,004.95 -> miles es ',', decimal es '.'
          clean = clean.replaceAll(',', '');
        }
      } else if (clean.contains(',')) {
        // Solo coma decimal: 896,12 -> 896.12
        clean = clean.replaceAll(',', '.');
      }
      return double.parse(clean);
    } catch (e) {
      return null;
    }
  }

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
      DateTime ahora = DateTime.now();
      String hoyStr = DateFormat('dd/MM/yyyy').format(ahora);
      List<String> hist = storage.getHistorial();

      final binanceFuture = Future.wait([
        _fetchBinance("BUY"),
        _fetchBinance("SELL")
      ]).then((results) {
        binanceCompra = results[0];
        binanceVenta = results[1];
        if (binanceCompra == 0.0 || binanceVenta == 0.0) {
          offlineMode = true;
          binanceCompra = storage.buscarUltimoValido("Binance Compra", "", hist);
          binanceVenta = storage.buscarUltimoValido("Binance Venta", "", hist);
        }
      });

      final bcvFuture = () async {
        double savedDolar = storage.buscarUltimoValido("BCV Dolar", hoyStr, hist);
        double savedEuro = storage.buscarUltimoValido("BCV Euro", hoyStr, hist);

        try {
          final resWeb = await http.get(Uri.parse('https://www.bcv.org.ve/')).timeout(const Duration(seconds: 10));
          if (resWeb.statusCode == 200) {
            var doc = parse(resWeb.body);
            var usdT = doc.getElementById('dolar')?.querySelector('strong')?.text.trim();
            var eurT = doc.getElementById('euro')?.querySelector('strong')?.text.trim();
            var fechaT = doc.querySelector('.date-display-single')?.text.trim() ?? "";
            
            double? usdWeb = parseRate(usdT);
            double? eurWeb = parseRate(eurT);

            if (usdWeb != null && eurWeb != null && usdWeb > 20.0) {
              DateTime? fechaBCV = _parseBCVDate(fechaT);
              
              bool esTasaFuturaReal = false;
              if (fechaBCV != null) {
                DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);
                if (fechaBCV.isAfter(hoy)) {
                  esTasaFuturaReal = true;
                }
              }

              if (esTasaFuturaReal) {
                esTasaFutura = true;
                double backupDolar = storage.buscarUltimoValido("BCV Dolar", "", hist);
                double backupEuro = storage.buscarUltimoValido("BCV Euro", "", hist);
                
                bcvDolar = (backupDolar > 0) ? backupDolar : usdWeb;
                bcvEuro = (backupEuro > 0) ? backupEuro : eurWeb;
                infoTasa = "Tasa anterior vigente en curso";
                futureTasaInfo = "¡Atención! Nuevas tasas para $fechaT\nUSD: ${usdWeb.toStringAsFixed(2)} | EUR: ${eurWeb.toStringAsFixed(2)}";
              } else {
                bcvDolar = usdWeb; 
                bcvEuro = eurWeb; 
                infoTasa = "Tasas BCV: $fechaT"; 
                esTasaFutura = false; 
              }
            } else {
              throw Exception("No se pudieron parsear las tasas del BCV o valor inválido");
            }
          } else {
            throw Exception("Error HTTP ${resWeb.statusCode} al consultar BCV");
          }
        } catch (e) {
          offlineMode = true;
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
      }();

      await Future.wait([binanceFuture, bcvFuture]);

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
      final res = await http.post(
        Uri.parse('https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "asset": "USDT",
          "fiat": "VES",
          "tradeType": type,
          "rows": 1,
          "page": 1,
          "publisherType": "merchant",
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body);
      if (data != null && data['data'] != null && (data['data'] as List).isNotEmpty) {
        var priceStr = data['data'][0]['adv']?['price']?.toString();
        if (priceStr != null) {
          return parseRate(priceStr) ?? 0.0;
        }
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
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
