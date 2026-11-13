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
  final bool guardarBcvEnHistorial;

  ApiResult({
    required this.binanceCompra,
    required this.binanceVenta,
    required this.bcvDolar,
    required this.bcvEuro,
    required this.infoTasa,
    required this.esTasaFutura,
    this.offlineMode = false,
    this.futureTasaInfo = "",
    this.guardarBcvEnHistorial = true,
  });
}

class BcvResolution {
  final double bcvDolar;
  final double bcvEuro;
  final String infoTasa;
  final bool esTasaFutura;
  final String futureTasaInfo;
  final bool guardarBcvEnHistorial;

  const BcvResolution({
    required this.bcvDolar,
    required this.bcvEuro,
    required this.infoTasa,
    required this.esTasaFutura,
    required this.futureTasaInfo,
    required this.guardarBcvEnHistorial,
  });
}

/// Representa un anuncio real publicado en el mercado P2P de Binance.
class BinanceAd {
  final double price;
  final double minAmount;
  final double maxAmount;
  final String nickName;
  final double finishRate;

  BinanceAd({
    required this.price,
    required this.minAmount,
    required this.maxAmount,
    required this.nickName,
    required this.finishRate,
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

  /// Determina la tasa BCV activa según el día actual y la fecha valor publicada.
  /// Solo aplica anticipadamente una tasa futura cuando es VIERNES y la tasa
  /// corresponde al LUNES (o MARTES si el lunes es feriado bancario).
  static BcvResolution resolveBcvRates({
    required DateTime ahora,
    required DateTime? fechaBCV,
    required String fechaTexto,
    required double usdWeb,
    required double eurWeb,
    required double tasaHoyDolar,
    required double tasaHoyEuro,
    required double backupDolar,
    required double backupEuro,
  }) {
    final DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final bool esTasaFuturaReal = fechaBCV != null && fechaBCV.isAfter(hoy);

    if (!esTasaFuturaReal) {
      return BcvResolution(
        bcvDolar: usdWeb,
        bcvEuro: eurWeb,
        infoTasa: "Tasas BCV: $fechaTexto",
        esTasaFutura: false,
        futureTasaInfo: "",
        guardarBcvEnHistorial: true,
      );
    }

    final bool esViernes = ahora.weekday == DateTime.friday;
    final bool esProxSemana =
        fechaBCV.weekday == DateTime.monday ||
        fechaBCV.weekday == DateTime.tuesday;
    final int diffDias = fechaBCV.difference(hoy).inDays;
    final bool aplicarAnticipada =
        esViernes && esProxSemana && diffDias >= 1 && diffDias <= 4;

    if (aplicarAnticipada) {
      return BcvResolution(
        bcvDolar: usdWeb,
        bcvEuro: eurWeb,
        infoTasa: "Tasa de $fechaTexto aplicada (viernes)",
        esTasaFutura: true,
        futureTasaInfo:
            "📢 Tasa oficial para $fechaTexto aplicada por ser viernes\nUSD: ${usdWeb.toStringAsFixed(2)} | EUR: ${eurWeb.toStringAsFixed(2)}",
        guardarBcvEnHistorial: true,
      );
    }

    // Para lunes a jueves cuando se publica la tasa de mañana:
    // La tasa activa NUNCA debe ser la tasa futura usdWeb/eurWeb.
    // Descartamos cualquier valor que sea idéntico a la tasa futura por contaminación previa.
    final double safeTasaHoyDolar =
        (tasaHoyDolar > 0 && (tasaHoyDolar - usdWeb).abs() > 0.001)
            ? tasaHoyDolar
            : 0.0;
    final double safeTasaHoyEuro =
        (tasaHoyEuro > 0 && (tasaHoyEuro - eurWeb).abs() > 0.001)
            ? tasaHoyEuro
            : 0.0;

    final double safeBackupDolar =
        (backupDolar > 0 && (backupDolar - usdWeb).abs() > 0.001)
            ? backupDolar
            : 0.0;
    final double safeBackupEuro =
        (backupEuro > 0 && (backupEuro - eurWeb).abs() > 0.001)
            ? backupEuro
            : 0.0;

    final double dolarVigente = safeTasaHoyDolar > 0
        ? safeTasaHoyDolar
        : (safeBackupDolar > 0 ? safeBackupDolar : usdWeb);
    final double euroVigente = safeTasaHoyEuro > 0
        ? safeTasaHoyEuro
        : (safeBackupEuro > 0 ? safeBackupEuro : eurWeb);

    final String hoyStr = DateFormat('dd/MM/yyyy').format(ahora);
    final bool hayVigente =
        (safeTasaHoyDolar > 0 && safeTasaHoyEuro > 0) ||
        (safeBackupDolar > 0 && safeBackupEuro > 0);

    return BcvResolution(
      bcvDolar: dolarVigente,
      bcvEuro: euroVigente,
      infoTasa: hayVigente
          ? "Tasa vigente en curso ($hoyStr)"
          : "Sin tasa previa en caché · Publicada: $fechaTexto",
      esTasaFutura: true,
      futureTasaInfo:
          "📢 Próxima tasa para $fechaTexto\nUSD: ${usdWeb.toStringAsFixed(2)} | EUR: ${eurWeb.toStringAsFixed(2)}",
      guardarBcvEnHistorial: false,
    );
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
    bool guardarBcvEnHistorial = true;

    try {
      DateTime ahora = DateTime.now();
      String hoyStr = DateFormat('dd/MM/yyyy').format(ahora);
      List<String> hist = storage.getHistorial();

      final binanceFuture =
          Future.wait([_fetchBinance("BUY"), _fetchBinance("SELL")]).then((
            results,
          ) {
            binanceCompra = results[0];
            binanceVenta = results[1];
            if (binanceCompra == 0.0 || binanceVenta == 0.0) {
              offlineMode = true;
              binanceCompra = storage.buscarUltimoValido(
                "Binance Compra",
                "",
                hist,
              );
              binanceVenta = storage.buscarUltimoValido(
                "Binance Venta",
                "",
                hist,
              );
            }
          });

      final bcvFuture = () async {
        double savedDolar = storage.buscarUltimoValido(
          "BCV Dolar",
          hoyStr,
          hist,
        );
        double savedEuro = storage.buscarUltimoValido("BCV Euro", hoyStr, hist);
        double tasaHoyDolar = storage.getTasaGuardadaPorFecha('USD', hoyStr);
        if (tasaHoyDolar <= 0) tasaHoyDolar = savedDolar;
        double tasaHoyEuro = storage.getTasaGuardadaPorFecha('EUR', hoyStr);
        if (tasaHoyEuro <= 0) tasaHoyEuro = savedEuro;

        try {
          final resWeb = await http
              .get(Uri.parse('https://www.bcv.org.ve/'))
              .timeout(const Duration(seconds: 10));
          if (resWeb.statusCode == 200) {
            var doc = parse(resWeb.body);
            var usdT = doc
                .getElementById('dolar')
                ?.querySelector('strong')
                ?.text
                .trim();
            var eurT = doc
                .getElementById('euro')
                ?.querySelector('strong')
                ?.text
                .trim();
            var fechaT =
                doc.querySelector('.date-display-single')?.text.trim() ?? "";

            double? usdWeb = parseRate(usdT);
            double? eurWeb = parseRate(eurT);

            if (usdWeb != null && eurWeb != null && usdWeb > 20.0) {
              DateTime? fechaBCV = _parseBCVDate(fechaT);
              final DateTime hoy = DateTime(ahora.year, ahora.month, ahora.day);
              final bool esTasaFuturaReal =
                  fechaBCV != null && fechaBCV.isAfter(hoy);
              final bool esViernes = ahora.weekday == DateTime.friday;
              final bool esProxSemana =
                  fechaBCV != null &&
                  (fechaBCV.weekday == DateTime.monday ||
                      fechaBCV.weekday == DateTime.tuesday);
              final int diffDias =
                  fechaBCV != null ? fechaBCV.difference(hoy).inDays : 0;
              final bool aplicarAnticipada =
                  esViernes && esProxSemana && diffDias >= 1 && diffDias <= 4;

              if (fechaBCV != null) {
                // Guarda la tasa bajo su fecha valor oficial publicada
                await storage.guardarTasaPorFecha(
                  DateFormat('dd/MM/yyyy').format(fechaBCV),
                  usdWeb,
                  eurWeb,
                );
              }

              if (!esTasaFuturaReal) {
                // Si la tasa publicada corresponde al día de hoy, se asegura en caché de hoy
                await storage.guardarTasaPorFecha(hoyStr, usdWeb, eurWeb);
              }

              // Si es tasa futura y NO se debe aplicar de inmediato (Lun-Jue tarde):
              if (esTasaFuturaReal && !aplicarAnticipada) {
                // Purgamos del historial cualquier registro que haya guardado la tasa futura hoy por error
                hist = await storage.purgarTasasContaminadas(
                  usdFuturo: usdWeb,
                  eurFuturo: eurWeb,
                  fechaHoy: hoyStr,
                );

                // Recalculamos tasas vigentes excluyendo la tasa futura
                savedDolar = storage.buscarUltimoValido(
                  "BCV Dolar",
                  hoyStr,
                  hist,
                  tasaAExcluir: usdWeb,
                );
                savedEuro = storage.buscarUltimoValido(
                  "BCV Euro",
                  hoyStr,
                  hist,
                  tasaAExcluir: eurWeb,
                );

                tasaHoyDolar = storage.getTasaGuardadaPorFecha('USD', hoyStr);
                if (tasaHoyDolar <= 0 ||
                    (tasaHoyDolar - usdWeb).abs() < 0.001) {
                  tasaHoyDolar = savedDolar;
                }

                tasaHoyEuro = storage.getTasaGuardadaPorFecha('EUR', hoyStr);
                if (tasaHoyEuro <= 0 ||
                    (tasaHoyEuro - eurWeb).abs() < 0.001) {
                  tasaHoyEuro = savedEuro;
                }
              }

              final double backupDolar = storage.buscarUltimoValido(
                "BCV Dolar",
                "",
                hist,
                tasaAExcluir:
                    (esTasaFuturaReal && !aplicarAnticipada) ? usdWeb : 0.0,
              );
              final double backupEuro = storage.buscarUltimoValido(
                "BCV Euro",
                "",
                hist,
                tasaAExcluir:
                    (esTasaFuturaReal && !aplicarAnticipada) ? eurWeb : 0.0,
              );

              final resolution = resolveBcvRates(
                ahora: ahora,
                fechaBCV: fechaBCV,
                fechaTexto: fechaT,
                usdWeb: usdWeb,
                eurWeb: eurWeb,
                tasaHoyDolar: tasaHoyDolar,
                tasaHoyEuro: tasaHoyEuro,
                backupDolar: backupDolar,
                backupEuro: backupEuro,
              );

              bcvDolar = resolution.bcvDolar;
              bcvEuro = resolution.bcvEuro;
              infoTasa = resolution.infoTasa;
              esTasaFutura = resolution.esTasaFutura;
              futureTasaInfo = resolution.futureTasaInfo;
              guardarBcvEnHistorial = resolution.guardarBcvEnHistorial;
            } else {
              throw Exception(
                "No se pudieron parsear las tasas del BCV o valor inválido",
              );
            }
          } else {
            throw Exception("Error HTTP ${resWeb.statusCode} al consultar BCV");
          }
        } catch (e) {
          offlineMode = true;
          guardarBcvEnHistorial = false;
          if (tasaHoyDolar > 0 && tasaHoyEuro > 0) {
            bcvDolar = tasaHoyDolar;
            bcvEuro = tasaHoyEuro;
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
      guardarBcvEnHistorial = false;
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
      guardarBcvEnHistorial: guardarBcvEnHistorial,
    );
  }

  Future<double> _fetchBinance(String type) async {
    try {
      final ads = await _queryBinanceAds(
        tradeType: type,
        publisherType: "merchant",
        rows: 1,
      );
      if (ads.isNotEmpty) {
        return ads.first.price;
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Consulta anuncios reales en Binance P2P filtrando por monto en Bs y método de pago.
  Future<List<BinanceAd>> fetchBinanceAds({
    required String tradeType,
    double? transAmountBs,
    String? payType,
    int rows = 5,
  }) async {
    try {
      List<BinanceAd> ads = await _queryBinanceAds(
        tradeType: tradeType,
        transAmountBs: transAmountBs,
        payType: payType,
        publisherType: "merchant",
        rows: rows,
      );
      if (ads.isEmpty) {
        // Fallback: buscar también entre anunciantes regulares si no hay comerciantes verificados para ese filtro
        ads = await _queryBinanceAds(
          tradeType: tradeType,
          transAmountBs: transAmountBs,
          payType: payType,
          publisherType: null,
          rows: rows,
        );
      }
      return ads;
    } catch (e) {
      return [];
    }
  }

  Future<List<BinanceAd>> _queryBinanceAds({
    required String tradeType,
    double? transAmountBs,
    String? payType,
    String? publisherType,
    int rows = 5,
  }) async {
    final Map<String, dynamic> payload = {
      "asset": "USDT",
      "fiat": "VES",
      "tradeType": tradeType,
      "rows": rows,
      "page": 1,
    };
    if (publisherType != null) {
      payload["publisherType"] = publisherType;
    }
    if (transAmountBs != null && transAmountBs > 0) {
      payload["transAmount"] = transAmountBs.toStringAsFixed(0);
    }
    if (payType != null && payType.isNotEmpty) {
      payload["payTypes"] = [payType];
    }

    final res = await http
        .post(
          Uri.parse(
            'https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search',
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 10));

    final data = jsonDecode(res.body);
    if (data == null || data['data'] == null) return [];

    final List<BinanceAd> ads = [];
    for (final item in data['data']) {
      final adv = item['adv'];
      final advertiser = item['advertiser'];
      if (adv == null) continue;

      final price = parseRate(adv['price']?.toString());
      if (price == null || price <= 0) continue;

      final minAmt = parseRate(adv['minSingleTransAmount']?.toString()) ?? 0.0;
      final maxAmt =
          parseRate(
            adv['dynamicMaxSingleTransAmount']?.toString() ??
                adv['maxSingleTransAmount']?.toString(),
          ) ??
          0.0;
      final nick = advertiser?['nickName']?.toString() ?? 'Comerciante';
      final finishRate =
          double.tryParse(advertiser?['monthFinishRate']?.toString() ?? '0') ??
          0.0;

      ads.add(
        BinanceAd(
          price: price,
          minAmount: minAmt,
          maxAmount: maxAmt,
          nickName: nick,
          finishRate: finishRate,
        ),
      );
    }
    return ads;
  }

  // Nueva función matemática para transformar el texto del BCV en una Fecha Real
  DateTime? _parseBCVDate(String text) {
    try {
      text = text.toLowerCase();
      List<String> meses = [
        "enero",
        "febrero",
        "marzo",
        "abril",
        "mayo",
        "junio",
        "julio",
        "agosto",
        "septiembre",
        "octubre",
        "noviembre",
        "diciembre",
      ];

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
      int year = yearMatch != null
          ? int.parse(yearMatch.group(1)!)
          : DateTime.now().year;

      return DateTime(year, month, day);
    } catch (e) {
      return null;
    }
  }
}
