import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import '../services/storage_service.dart';

class HistoryScreen extends StatelessWidget {
  final List<String> historial;
  final Function(List<String>) onHistorialUpdate;
  final StorageService storage;
  
  const HistoryScreen({
    super.key, 
    required this.historial,
    required this.onHistorialUpdate,
    required this.storage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historial Dañaman"), actions: [
        IconButton(icon: const Icon(Icons.file_upload), onPressed: () => _importarCSV(context)),
        IconButton(icon: const Icon(Icons.file_download), onPressed: () => _exportarCSV(historial)),
      ]),
      body: historial.isEmpty ? const Center(child: Text("Sin registros")) : ListView(
        padding: const EdgeInsets.all(10),
        children: [
          _buildFolder("BCV Dolar", Colors.blue), 
          _buildFolder("BCV Euro", Colors.purple), 
          _buildFolder("Binance Compra", Colors.orange), 
          _buildFolder("Binance Venta", Colors.deepOrange)
        ],
      ),
    );
  }

  Widget _buildFolder(String cat, Color col) {
    List<String> filtrado = historial.where((e) => e.startsWith(cat)).toList();
    double min = 0.0, max = 0.0;
    if (filtrado.isNotEmpty) {
      List<double> val = filtrado.map((e) => double.tryParse(e.split('|')[1]) ?? 0.0).toList();
      min = val.reduce((c, n) => c < n ? c : n); 
      max = val.reduce((c, n) => c > n ? c : n);
    }
    return Card(elevation: 0, shape: RoundedRectangleBorder(side: BorderSide(color: col.withAlpha(51)), borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(leading: Icon(Icons.folder, color: col), title: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), subtitle: Text("${filtrado.length} registros"),
        children: [
          if (filtrado.isNotEmpty) Container(padding: const EdgeInsets.all(8), color: col.withAlpha(13), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_extremoText("MÍNIMO", min, Colors.green), _extremoText("MÁXIMO", max, Colors.red)])),
          ...filtrado.map((i) { var p = i.split('|'); return ListTile(dense: true, title: Text(p[1], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${p[2]} - ${p[3]}")); }).toList(),
        ],
      ),
    );
  }

  Widget _extremoText(String l, double v, Color c) => Column(children: [Text(l, style: TextStyle(fontSize: 9, color: c)), Text(v.toStringAsFixed(2), style: TextStyle(fontSize: 16, color: c))]);

  Future<void> _exportarCSV(List<String> h) async {
    String csv = "Indicador,Tasa,Fecha,Hora\n" + h.map((e) => e.replaceAll('|', ',')).join('\n');
    final dir = await getTemporaryDirectory();
    final file = File("${dir.path}/historial_tasas.csv");
    await file.writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Exportación Dañaman');
  }

  Future<void> _importarCSV(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        String contents = await file.readAsString();
        List<String> lines = contents.split('\n');
        
        if (lines.isNotEmpty && lines[0].startsWith('Indicador')) {
          lines.removeAt(0); // Remover cabecera
        }
        
        List<String> nuevosRegistros = [];
        for (String line in lines) {
          if (line.trim().isEmpty) continue;
          List<String> parts = line.split(',');
          if (parts.length >= 4) {
            String ind = parts[0];
            String tas = parts[1];
            String fec = parts[2];
            String hor = parts.sublist(3).join(','); // Por si la hora tiene comas
            nuevosRegistros.add("$ind|$tas|$fec|$hor");
          }
        }
        
        if (nuevosRegistros.isNotEmpty) {
          List<String> merged = await storage.mergeHistorial(nuevosRegistros);
          onHistorialUpdate(merged);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Historial importado con éxito")));
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El archivo no contiene registros válidos")));
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al importar historial")));
      }
    }
  }
}
