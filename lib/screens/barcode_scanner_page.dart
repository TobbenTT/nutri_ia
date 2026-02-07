import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  bool _isScanning = true;
  final MobileScannerController _cameraController = MobileScannerController();

  // Función para buscar en OpenFoodFacts
  Future<void> _fetchProductData(String barcode) async {
    setState(() => _isScanning = false); // Pausar para no leer mil veces

    // API Gratuita de OpenFoodFacts
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');

    try {
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF88)))
      );

      final response = await http.get(url);

      if (mounted) Navigator.pop(context); // Cerrar loading

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 1) {
          final product = data['product'];
          final nutriments = product['nutriments'];

          // Preparar datos para devolver (Protegemos contra nulos)
          final Map<String, dynamic> result = {
            'name': product['product_name'] ?? 'Producto Escaneado',
            'calories': (nutriments['energy-kcal_100g'] ?? 0).round(),
            'protein': (nutriments['proteins_100g'] ?? 0).round(),
            'carbs': (nutriments['carbohydrates_100g'] ?? 0).round(),
            'fat': (nutriments['fat_100g'] ?? 0).round(),
            // Micros
            'sugar': (nutriments['sugars_100g'] ?? 0).round(),
            'fiber': (nutriments['fiber_100g'] ?? 0).round(),
            // Sodio suele venir en gramos, lo pasamos a mg
            'sodium': ((nutriments['sodium_100g'] ?? 0) * 1000).round(),
          };

          if (mounted) {
            Navigator.pop(context, result); // ✅ DEVOLVER DATOS AL DASHBOARD
          }
        } else {
          _showError("Producto no encontrado en la base de datos.");
        }
      } else {
        _showError("Error de conexión con el servidor.");
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Cerrar loading si falló
      _showError("Error: $e");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isScanning = true); // Reanudar escáner
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Escanear Barcode", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _cameraController.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: (capture) {
              if (!_isScanning) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _fetchProductData(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // Marco visual
          Center(
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF00FF88), width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 80, left: 0, right: 0,
            child: Text("Apunta al código de barras", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 16, backgroundColor: Colors.black54)),
          ),
        ],
      ),
    );
  }
}