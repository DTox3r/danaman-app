import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'p2p_estimator_screen.dart';

class MainNavigation extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final StorageService storage;

  const MainNavigation({
    super.key,
    required this.onThemeToggle,
    required this.storage,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<String> historial = [];
  bool _bankUseComma = true;

  @override
  void initState() {
    super.initState();
    historial = widget.storage.getHistorial();
    _bankUseComma = widget.storage.getBankUseComma();
  }

  void _updateHistorial(List<String> nuevo) {
    setState(() => historial = nuevo);
  }

  void _toggleBankFormat() async {
    final next = !_bankUseComma;
    setState(() => _bankUseComma = next);
    await widget.storage.setBankUseComma(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          HomeScreen(
            onThemeToggle: widget.onThemeToggle,
            onHistorialUpdate: _updateHistorial,
            storage: widget.storage,
            bankUseComma: _bankUseComma,
            onBankFormatToggle: _toggleBankFormat,
          ),
          HistoryScreen(
            historial: historial,
            onHistorialUpdate: _updateHistorial,
            storage: widget.storage,
          ),
          P2pEstimatorScreen(
            storage: widget.storage,
            onThemeToggle: widget.onThemeToggle,
            historial: historial,
            bankUseComma: _bankUseComma,
            onBankFormatToggle: _toggleBankFormat,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate),
            label: 'Calculadora',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
          NavigationDestination(
            icon: Icon(Icons.price_change),
            label: 'Estimador P2P',
          ),
        ],
      ),
    );
  }
}
