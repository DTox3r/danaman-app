import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/storage_service.dart';
import 'screens/main_navigation.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final StorageService storageService = StorageService(prefs);
  runApp(ConvertidorApp(storage: storageService));
}

class ConvertidorApp extends StatefulWidget {
  final StorageService storage;
  const ConvertidorApp({super.key, required this.storage});
  @override
  State<ConvertidorApp> createState() => _ConvertidorAppState();
}

class _ConvertidorAppState extends State<ConvertidorApp> {
  late ThemeMode _themeMode;

  @override
  void initState() {
    super.initState();
    final saved = widget.storage.prefs.getString('theme_mode');
    if (saved == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      // Predeterminado: modo light
      _themeMode = ThemeMode.light;
    }
  }

  void toggleTheme() async {
    setState(
      () => _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light,
    );
    await widget.storage.prefs.setString(
      'theme_mode',
      _themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Convertidor Pro de Tasas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.orange,
        brightness: Brightness.dark,
      ),
      themeMode: _themeMode,
      home: MainNavigation(onThemeToggle: toggleTheme, storage: widget.storage),
    );
  }
}
