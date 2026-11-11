import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';

class P2pEstimateResult {
  final double usdtBrutos;
  final double usdtNetos;
  final double totalBs;
  final double tasaEfectiva;

  const P2pEstimateResult({
    required this.usdtBrutos,
    required this.usdtNetos,
    required this.totalBs,
    required this.tasaEfectiva,
  });

  static const empty = P2pEstimateResult(
    usdtBrutos: 0.0,
    usdtNetos: 0.0,
    totalBs: 0.0,
    tasaEfectiva: 0.0,
  );
}

class P2pCalculator {
  static double _round2(double value) => (value * 100).roundToDouble() / 100;
  static double _floor2(double value) =>
      ((value * 100) + 1e-9).floorToDouble() / 100;
  static double _ceil2(double value) =>
      ((value * 100) - 1e-9).ceilToDouble() / 100;

  /// Calcula el estimado replicando el truncamiento a 2 decimales de Binance P2P.
  static P2pEstimateResult calcular({
    required bool isCompra,
    required bool isPorUsdt,
    required double monto,
    required double tasa,
    required double feeUsdt,
  }) {
    if (monto <= 0 || tasa <= 0) return P2pEstimateResult.empty;
    final double fee = feeUsdt < 0 ? 0.0 : feeUsdt;

    if (isCompra) {
      if (isPorUsdt) {
        // Quiero recibir [monto] USDT netos -> debo ordenar monto + fee
        final double brutos = _round2(monto + fee);
        final double totalBs = _ceil2(brutos * tasa);
        final double tasaReal = totalBs / monto;
        return P2pEstimateResult(
          usdtBrutos: brutos,
          usdtNetos: _round2(monto),
          totalBs: totalBs,
          tasaEfectiva: tasaReal,
        );
      } else {
        // Voy a pagar [monto] Bs -> Binance trunca a 2 decimales y resta comisión
        final double brutos = _floor2(monto / tasa);
        final double netos = brutos > fee ? _round2(brutos - fee) : 0.0;
        final double tasaReal = netos > 0 ? (monto / netos) : 0.0;
        return P2pEstimateResult(
          usdtBrutos: brutos,
          usdtNetos: netos,
          totalBs: monto,
          tasaEfectiva: tasaReal,
        );
      }
    } else {
      if (isPorUsdt) {
        // Quiero vender [monto] USDT -> recibo Bs por (monto - fee)
        final double liquidados = monto > fee ? _round2(monto - fee) : 0.0;
        final double totalBs = _floor2(liquidados * tasa);
        final double tasaReal = monto > 0 ? (totalBs / monto) : 0.0;
        return P2pEstimateResult(
          usdtBrutos: _round2(monto),
          usdtNetos: liquidados,
          totalBs: totalBs,
          tasaEfectiva: tasaReal,
        );
      } else {
        // Quiero recibir [monto] Bs vendiendo USDT -> orden + fee
        final double liquidados = _ceil2(monto / tasa);
        final double brutos = _round2(liquidados + fee);
        final double tasaReal = brutos > 0 ? (monto / brutos) : 0.0;
        return P2pEstimateResult(
          usdtBrutos: brutos,
          usdtNetos: liquidados,
          totalBs: monto,
          tasaEfectiva: tasaReal,
        );
      }
    }
  }
}

class P2pEstimatorScreen extends StatefulWidget {
  final StorageService storage;
  final VoidCallback onThemeToggle;
  final List<String> historial;
  final bool bankUseComma;
  final VoidCallback? onBankFormatToggle;

  const P2pEstimatorScreen({
    super.key,
    required this.storage,
    required this.onThemeToggle,
    this.historial = const [],
    this.bankUseComma = true,
    this.onBankFormatToggle,
  });

  @override
  State<P2pEstimatorScreen> createState() => _P2pEstimatorScreenState();
}

class _P2pEstimatorScreenState extends State<P2pEstimatorScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _feeController = TextEditingController(
    text: "0.06",
  );
  final TextEditingController _rateController = TextEditingController();

  static const Map<String, String> _metodosPago = {
    "": "Todos los métodos",
    "PagoMovil": "Pago Móvil",
    "Banesco": "Banesco",
    "BancoDeVenezuela": "Banco de Venezuela",
    "Mercantil": "Mercantil",
    "Provincial": "Provincial",
    "BNCBancoNacional": "BNC",
    "Bancamiga": "Bancamiga",
    "BancoDelTesoro": "Banco del Tesoro",
  };

  String operacion = "COMPRAR USDT";
  bool porUsdt = true;
  String payType = "";
  double tasaBase = 0.0;
  P2pEstimateResult resultado = P2pEstimateResult.empty;

  bool isSearchingAds = false;
  bool rateEditedManually = false;
  List<BinanceAd> liveAds = [];
  String? adsStatusMsg;
  Timer? _debounce;
  int _searchSeq = 0;

  final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_VE',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    payType = widget.storage.prefs.getString('p2p_pay_type') ?? "";
    if (!_metodosPago.containsKey(payType)) payType = "";
    final savedFee = widget.storage.prefs.getString('p2p_fee');
    if (savedFee != null && savedFee.isNotEmpty) {
      _feeController.text = savedFee;
    }
    _cargarTasaDesdeHistorial();
    _buscarAnunciosEnVivo();
  }

  @override
  void didUpdateWidget(covariant P2pEstimatorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.historial != oldWidget.historial &&
        liveAds.isEmpty &&
        !rateEditedManually) {
      _cargarTasaDesdeHistorial();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    _feeController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  void _cargarTasaDesdeHistorial() {
    final List<String> hist = widget.historial.isNotEmpty
        ? widget.historial
        : widget.storage.getHistorial();
    // COMPRAR USDT en Binance corresponde a tradeType BUY ("Binance Compra")
    // VENDER USDT en Binance corresponde a tradeType SELL ("Binance Venta")
    final String key = (operacion == "COMPRAR USDT")
        ? "Binance Compra"
        : "Binance Venta";
    final double cached = widget.storage.buscarUltimoValido(key, "", hist);
    if (cached > 0) {
      tasaBase = cached;
      _rateController.text = cached.toStringAsFixed(2);
    }
    _calcular();
  }

  void _onAmountChanged() {
    _calcular();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 650), () {
      if (mounted) {
        rateEditedManually = false;
        _buscarAnunciosEnVivo();
      }
    });
  }

  Future<void> _buscarAnunciosEnVivo() async {
    final int reqId = ++_searchSeq;
    setState(() {
      isSearchingAds = true;
      adsStatusMsg = null;
    });

    final double monto = ApiService.parseRate(_amountController.text) ?? 0.0;
    final double fee = ApiService.parseRate(_feeController.text) ?? 0.06;
    double? transAmountBs;

    if (monto > 0) {
      if (porUsdt) {
        final double refTasa = tasaBase > 0 ? tasaBase : 1000.0;
        transAmountBs = (monto + fee) * refTasa;
      } else {
        transAmountBs = monto;
      }
    }

    final String tradeType = (operacion == "COMPRAR USDT") ? "BUY" : "SELL";
    final ads = await _apiService.fetchBinanceAds(
      tradeType: tradeType,
      transAmountBs: transAmountBs,
      payType: payType.isEmpty ? null : payType,
      rows: 5,
    );

    if (!mounted || reqId != _searchSeq) return;

    setState(() {
      isSearchingAds = false;
      liveAds = ads;
      if (ads.isNotEmpty) {
        if (!rateEditedManually) {
          tasaBase = ads.first.price;
          _rateController.text = tasaBase.toStringAsFixed(2);
        }
        adsStatusMsg = transAmountBs != null && transAmountBs > 0
            ? "Tasa real para ~${_currencyFormat.format(transAmountBs)} Bs"
            : "Mejor tasa vigente en Binance P2P";
      } else {
        adsStatusMsg = "Sin conexión o sin anuncios para este monto/método";
      }
    });
    _calcular();
  }

  void _calcular() {
    final double monto = ApiService.parseRate(_amountController.text) ?? 0.0;
    final double fee = ApiService.parseRate(_feeController.text) ?? 0.0;
    final double tasa = ApiService.parseRate(_rateController.text) ?? tasaBase;

    setState(() {
      tasaBase = tasa;
      resultado = P2pCalculator.calcular(
        isCompra: operacion == "COMPRAR USDT",
        isPorUsdt: porUsdt,
        monto: monto,
        tasa: tasa,
        feeUsdt: fee,
      );
    });
  }

  String _formatCompact(double v) {
    if (v >= 1000000) return "${(v / 1000000).toStringAsFixed(1)}M";
    if (v >= 1000) return "${(v / 1000).toStringAsFixed(0)}k";
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color txtCol = isDark ? Colors.white : Colors.black;
    final bool isCompra = operacion == "COMPRAR USDT";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Estimador P2P Binance"),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: widget.onThemeToggle,
          ),
          IconButton(
            icon: isSearchingAds
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: "Consultar tasa real en Binance",
            onPressed: isSearchingAds
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    rateEditedManually = false;
                    _buscarAnunciosEnVivo();
                  },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Operación en Binance
            DropdownButtonFormField<String>(
              initialValue: operacion,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Operación en Binance",
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: const [
                DropdownMenuItem(
                  value: "COMPRAR USDT",
                  child: Text(
                    "COMPRAR USDT (Pagas Bs)",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: "VENDER USDT",
                  child: Text(
                    "VENDER USDT (Recibes Bs)",
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    operacion = v;
                    rateEditedManually = false;
                  });
                  _cargarTasaDesdeHistorial();
                  _buscarAnunciosEnVivo();
                }
              },
            ),
            const SizedBox(height: 12),

            // Método de pago para filtrar límites y bancos reales
            DropdownButtonFormField<String>(
              initialValue: payType,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: "Método de Pago (Filtro Binance)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_outlined),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              items: _metodosPago.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    payType = v;
                    rateEditedManually = false;
                  });
                  widget.storage.prefs.setString('p2p_pay_type', v);
                  _buscarAnunciosEnVivo();
                }
              },
            ),
            const SizedBox(height: 12),

            // Modo: Por USDT vs Por Bolívares (como en la app de Binance)
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  icon: Icon(Icons.attach_money),
                  label: Text("Por USDT"),
                ),
                ButtonSegment<bool>(
                  value: false,
                  icon: Icon(Icons.payments_outlined),
                  label: Text("Por Bolívares"),
                ),
              ],
              selected: {porUsdt},
              onSelectionChanged: (Set<bool> sel) {
                HapticFeedback.selectionClick();
                setState(() {
                  porUsdt = sel.first;
                  rateEditedManually = false;
                });
                _calcular();
                _buscarAnunciosEnVivo();
              },
            ),
            const SizedBox(height: 12),

            // Monto principal
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: TextStyle(
                fontSize: 18,
                color: txtCol,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                labelText: porUsdt
                    ? (isCompra
                          ? "Cantidad de USDT netos deseados"
                          : "Cantidad de USDT a vender")
                    : (isCompra
                          ? "Bolívares (VES) a pagar"
                          : "Bolívares (VES) a recibir"),
                border: const OutlineInputBorder(),
                prefixIcon: Icon(
                  porUsdt ? Icons.monetization_on : Icons.currency_exchange,
                  color: Colors.green,
                ),
                suffixIcon: _amountController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _amountController.clear();
                          _onAmountChanged();
                        },
                      )
                    : null,
              ),
              onChanged: (_) => _onAmountChanged(),
            ),
            const SizedBox(height: 12),

            // Tasa editable + Comisión lado a lado
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _rateController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: txtCol,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Tasa P2P (Bs)",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.trending_up),
                    ),
                    onChanged: (_) {
                      rateEditedManually = true;
                      _calcular();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _feeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: TextStyle(
                      color: txtCol,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: const InputDecoration(
                      labelText: "Comisión USDT",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      widget.storage.prefs.setString('p2p_fee', v.trim());
                      _calcular();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Anuncios reales encontrados en Binance para el monto
            if (adsStatusMsg != null || isSearchingAds)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (isSearchingAds)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        isSearchingAds
                            ? "Consultando ofertas reales en Binance..."
                            : adsStatusMsg!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (liveAds.isNotEmpty)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: liveAds.length > 4 ? 4 : liveAds.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final ad = liveAds[index];
                    final bool isSelected = (ad.price - tasaBase).abs() < 0.001;
                    return ChoiceChip(
                      selected: isSelected,
                      label: Text(
                        "${_currencyFormat.format(ad.price)} · ${_formatCompact(ad.minAmount)}-${_formatCompact(ad.maxAmount)}",
                        style: const TextStyle(fontSize: 11),
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        rateEditedManually = true;
                        _rateController.text = ad.price.toStringAsFixed(2);
                        _calcular();
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Tarjeta de Desglose Estilo Binance
            _buildResultadoCard(isCompra),
          ],
        ),
      ),
    );
  }

  void _copiarTexto(String texto, String mensaje) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: texto)).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), duration: const Duration(seconds: 2)),
      );
    });
  }

  Widget _buildResultadoCard(bool isCompra) {
    final bool mostrarResultadoEnBs = porUsdt;
    final String mainLabel;
    final String mainValue;
    final double usdtDisplay = isCompra
        ? resultado.usdtNetos
        : resultado.usdtBrutos;

    if (mostrarResultadoEnBs) {
      mainLabel = isCompra
          ? "TOTAL ESTIMADO A PAGAR (BS)"
          : "TOTAL ESTIMADO A RECIBIR (BS)";
      mainValue = "${_currencyFormat.format(resultado.totalBs)} Bs";
    } else {
      mainLabel = isCompra
          ? "RECIBES NETO EN BILLETERA"
          : "TOTAL USDT NECESARIOS";
      mainValue = "${usdtDisplay.toStringAsFixed(2)} USDT";
    }

    final String montoBanco = widget.storage.formatAmountForBank(
      resultado.totalBs,
      useComma: widget.bankUseComma,
    );
    final bool tieneBs = resultado.totalBs > 0;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.green.withAlpha(20),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.withAlpha(80)),
      ),
      child: Column(
        children: [
          _detailRow(
            isCompra ? "Cantidad total de la orden:" : "USDT liquidados:",
            "${(isCompra ? resultado.usdtBrutos : resultado.usdtNetos).toStringAsFixed(2)} USDT",
          ),
          const SizedBox(height: 4),
          _detailRow(
            "Comisión Binance:",
            "${isCompra ? '-' : ''}${(ApiService.parseRate(_feeController.text) ?? 0.0).toStringAsFixed(2)} USDT",
          ),
          const SizedBox(height: 4),
          _detailRow(
            "Tasa Real Efectiva (con comisión):",
            resultado.tasaEfectiva > 0
                ? "${_currencyFormat.format(resultado.tasaEfectiva)} Bs"
                : "---",
            bold: true,
          ),
          const Divider(height: 20),
          Text(
            mainLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: tieneBs
                ? () => _copiarTexto(
                    mostrarResultadoEnBs
                        ? montoBanco
                        : usdtDisplay.toStringAsFixed(2),
                    mostrarResultadoEnBs
                        ? "Monto copiado para banco: $montoBanco"
                        : "USDT copiado: ${usdtDisplay.toStringAsFixed(2)}",
                  )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  mainValue,
                  key: ValueKey<String>(mainValue),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (mostrarResultadoEnBs)
                FilledButton.tonalIcon(
                  onPressed: tieneBs
                      ? () => _copiarTexto(
                          montoBanco,
                          "Monto copiado para banco: $montoBanco",
                        )
                      : null,
                  icon: const Icon(Icons.account_balance_outlined, size: 18),
                  label: Text(
                    tieneBs
                        ? "Copiar para banco ($montoBanco)"
                        : "Copiar para banco",
                  ),
                )
              else ...[
                FilledButton.tonalIcon(
                  onPressed: usdtDisplay > 0
                      ? () => _copiarTexto(
                          usdtDisplay.toStringAsFixed(2),
                          "USDT copiado: ${usdtDisplay.toStringAsFixed(2)}",
                        )
                      : null,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text("Copiar USDT"),
                ),
                if (tieneBs)
                  OutlinedButton.icon(
                    onPressed: () => _copiarTexto(
                      montoBanco,
                      "Monto copiado para banco: $montoBanco",
                    ),
                    icon: const Icon(Icons.account_balance_outlined, size: 18),
                    label: Text("Copiar Bs ($montoBanco)"),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          ActionChip(
            avatar: const Icon(Icons.tune, size: 14),
            label: Text(
              widget.bankUseComma
                  ? "Formato banco: Coma (1234,56)"
                  : "Formato banco: Punto (1234.56)",
              style: const TextStyle(fontSize: 11),
            ),
            visualDensity: VisualDensity.compact,
            onPressed: widget.onBankFormatToggle == null
                ? null
                : () {
                    HapticFeedback.selectionClick();
                    widget.onBankFormatToggle!();
                  },
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
