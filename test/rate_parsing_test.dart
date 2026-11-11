import 'package:flutter_test/flutter_test.dart';
import 'package:convertidor_bcv/services/api_service.dart';
import 'package:convertidor_bcv/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ApiService Rate Parsing Tests', () {
    test('Parses BCV Euro with thousands separator (> 1000 Bs)', () {
      final val = ApiService.parseRate("1.004,95657762");
      expect(val, isNotNull);
      expect(val!, closeTo(1004.95657762, 0.00001));
    });

    test('Parses BCV Dolar with standard decimal comma', () {
      final val = ApiService.parseRate("896,12250000");
      expect(val, isNotNull);
      expect(val!, closeTo(896.1225, 0.0001));
    });

    test('Parses Anglo-Saxon format', () {
      final val = ApiService.parseRate("1,234.56");
      expect(val, isNotNull);
      expect(val!, closeTo(1234.56, 0.01));
    });

    test('Parses plain dot decimal', () {
      final val = ApiService.parseRate("1011.000");
      expect(val, isNotNull);
      expect(val!, closeTo(1011.0, 0.01));
    });

    test('Returns null on invalid text', () {
      expect(ApiService.parseRate(null), isNull);
      expect(ApiService.parseRate("invalido"), isNull);
      expect(ApiService.parseRate(""), isNull);
    });
  });

  group('StorageService Case Insensitivity Tests', () {
    test('buscarUltimoValido matches regardless of case', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = StorageService(prefs);

      List<String> hist = [
        "Binance Compra|1020.50|06/11/2026|01:00:00 PM",
        "Binance Venta|1015.00|06/11/2026|01:00:00 PM",
        "BCV Dolar|896.12|06/11/2026|01:00:00 PM",
      ];

      expect(storage.buscarUltimoValido("BINANCE COMPRA", "", hist), 1020.50);
      expect(storage.buscarUltimoValido("binance venta", "", hist), 1015.00);
      expect(storage.buscarUltimoValido("bcv dolar", "", hist), 896.12);
    });
  });

  group('ApiService Future Rate Resolution Rules', () {
    test('Tuesday night keeps Tuesday rate when Wednesday rate is published', () {
      final res = ApiService.resolveBcvRates(
        ahora: DateTime(2026, 11, 10, 20, 5), // Martes
        fechaBCV: DateTime(2026, 11, 11), // Miércoles
        fechaTexto: "Miércoles, 11 Noviembre 2026",
        usdWeb: 901.62,
        eurWeb: 1007.96,
        tasaHoyDolar: 898.00,
        tasaHoyEuro: 1002.00,
        backupDolar: 898.00,
        backupEuro: 1002.00,
      );

      expect(res.bcvDolar, 898.00);
      expect(res.bcvEuro, 1002.00);
      expect(res.esTasaFutura, isTrue);
      expect(res.guardarBcvEnHistorial, isFalse);
      expect(res.futureTasaInfo, contains("901.62"));
    });

    test('Thursday night keeps Thursday rate when Friday rate is published', () {
      final res = ApiService.resolveBcvRates(
        ahora: DateTime(2026, 11, 12, 18, 0), // Jueves
        fechaBCV: DateTime(2026, 11, 13), // Viernes
        fechaTexto: "Viernes, 13 Noviembre 2026",
        usdWeb: 905.00,
        eurWeb: 1012.00,
        tasaHoyDolar: 901.62,
        tasaHoyEuro: 1007.96,
        backupDolar: 901.62,
        backupEuro: 1007.96,
      );

      expect(res.bcvDolar, 901.62);
      expect(res.bcvEuro, 1007.96);
      expect(res.esTasaFutura, isTrue);
      expect(res.guardarBcvEnHistorial, isFalse);
    });

    test('Friday afternoon APPLIES Monday rate immediately', () {
      final res = ApiService.resolveBcvRates(
        ahora: DateTime(2026, 11, 13, 17, 0), // Viernes
        fechaBCV: DateTime(2026, 11, 16), // Lunes
        fechaTexto: "Lunes, 16 Noviembre 2026",
        usdWeb: 912.50,
        eurWeb: 1020.00,
        tasaHoyDolar: 905.00,
        tasaHoyEuro: 1012.00,
        backupDolar: 905.00,
        backupEuro: 1012.00,
      );

      expect(res.bcvDolar, 912.50);
      expect(res.bcvEuro, 1020.00);
      expect(res.esTasaFutura, isTrue);
      expect(res.guardarBcvEnHistorial, isTrue);
    });

    test('Friday afternoon APPLIES Tuesday rate if Monday is bank holiday', () {
      final res = ApiService.resolveBcvRates(
        ahora: DateTime(2026, 11, 13, 17, 0), // Viernes
        fechaBCV: DateTime(2026, 11, 17), // Martes (lunes bancario)
        fechaTexto: "Martes, 17 Noviembre 2026",
        usdWeb: 915.00,
        eurWeb: 1025.00,
        tasaHoyDolar: 905.00,
        tasaHoyEuro: 1012.00,
        backupDolar: 905.00,
        backupEuro: 1012.00,
      );

      expect(res.bcvDolar, 915.00);
      expect(res.bcvEuro, 1025.00);
      expect(res.esTasaFutura, isTrue);
      expect(res.guardarBcvEnHistorial, isTrue);
    });

    test('Same day rate uses web rate directly and saves to history', () {
      final res = ApiService.resolveBcvRates(
        ahora: DateTime(2026, 11, 11, 10, 0), // Miércoles
        fechaBCV: DateTime(2026, 11, 11), // Miércoles
        fechaTexto: "Miércoles, 11 Noviembre 2026",
        usdWeb: 901.62,
        eurWeb: 1007.96,
        tasaHoyDolar: 901.62,
        tasaHoyEuro: 1007.96,
        backupDolar: 898.00,
        backupEuro: 1002.00,
      );

      expect(res.bcvDolar, 901.62);
      expect(res.bcvEuro, 1007.96);
      expect(res.esTasaFutura, isFalse);
      expect(res.guardarBcvEnHistorial, isTrue);
    });
  });
}

