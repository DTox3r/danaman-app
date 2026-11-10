import 'package:flutter_test/flutter_test.dart';
import 'package:convertidor_bcv/screens/p2p_estimator_screen.dart';

void main() {
  group('P2pCalculator Tests (Binance P2P Exact Math)', () {
    test('Replicates Binance screenshot: 3240 VES @ 1066 Bs with 0.06 fee', () {
      final res = P2pCalculator.calcular(
        isCompra: true,
        isPorUsdt: false,
        monto: 3240.0,
        tasa: 1066.0,
        feeUsdt: 0.06,
      );

      expect(res.usdtBrutos, 3.03);
      expect(res.usdtNetos, 2.97);
      expect(res.totalBs, 3240.0);
      expect(res.tasaEfectiva, closeTo(1090.91, 0.01));
    });

    test('Buy 3.00 USDT net @ 1066 Bs with 0.06 fee', () {
      final res = P2pCalculator.calcular(
        isCompra: true,
        isPorUsdt: true,
        monto: 3.0,
        tasa: 1066.0,
        feeUsdt: 0.06,
      );

      expect(res.usdtBrutos, 3.06);
      expect(res.usdtNetos, 3.00);
      expect(res.totalBs, 3261.96);
      expect(res.tasaEfectiva, closeTo(1087.32, 0.01));
    });

    test('Buy 3.00 USDT net @ 1063.90 Bs rounds Bs up to avoid truncation loss', () {
      final res = P2pCalculator.calcular(
        isCompra: true,
        isPorUsdt: true,
        monto: 3.0,
        tasa: 1063.90,
        feeUsdt: 0.06,
      );

      // 3.06 * 1063.90 = 3255.534 -> ceiling to 3255.54 ensures >= 3.06 USDT
      expect(res.totalBs, 3255.54);
      final double verifyBrutos = ((res.totalBs / 1063.90) * 100 + 1e-9).floor() / 100;
      expect(verifyBrutos, 3.06);
    });

    test('Sell 10.00 USDT @ 1046.18 Bs with 0.06 fee', () {
      final res = P2pCalculator.calcular(
        isCompra: false,
        isPorUsdt: true,
        monto: 10.0,
        tasa: 1046.18,
        feeUsdt: 0.06,
      );

      expect(res.usdtBrutos, 10.00);
      expect(res.usdtNetos, 9.94);
      expect(res.totalBs, 10399.02);
    });

    test('Sell USDT to receive 10000 Bs @ 1046.18 Bs with 0.06 fee', () {
      final res = P2pCalculator.calcular(
        isCompra: false,
        isPorUsdt: false,
        monto: 10000.0,
        tasa: 1046.18,
        feeUsdt: 0.06,
      );

      // ceil2(10000 / 1046.18 = 9.5585...) = 9.56 + 0.06 = 9.62
      expect(res.usdtNetos, 9.56);
      expect(res.usdtBrutos, 9.62);
      expect(res.totalBs, 10000.0);
    });
  });
}

