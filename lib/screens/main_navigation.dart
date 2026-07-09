import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'home_screen.dart';
import 'history_screen.dart';

class MainNavigation extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final StorageService storage;

  const MainNavigation({super.key, required this.onThemeToggle, required this.storage});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<String> historial = [];

  @override
  void initState() {
    super.initState();
    historial = widget.storage.getHistorial();
  }

  void _updateHistorial(List<String> nuevo) {
    setState(() => historial = nuevo);
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
            storage: widget.storage
          ),
          HistoryScreen(
            historial: historial,
            onHistorialUpdate: _updateHistorial,
            storage: widget.storage,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.calculate), label: 'Calculadora'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Historial'),
        ],
      ),
    );
  }
}
