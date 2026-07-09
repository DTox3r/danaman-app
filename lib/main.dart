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
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(
      () => _themeMode = _themeMode == ThemeMode.light
          ? ThemeMode.dark
          : ThemeMode.light,
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
