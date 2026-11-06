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
}

