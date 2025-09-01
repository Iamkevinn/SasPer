// lib/screens/place_search_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:sasper/config/app_config.dart';
import 'package:uuid/uuid.dart'; // Necesitarás añadir `uuid` a tu pubspec.yaml

// Modelo simple para las predicciones
class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({required this.description, required this.placeId});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'],
      placeId: json['place_id'],
    );
  }
}

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  List<PlacePrediction> _predictions = [];
  bool _isLoading = false;
  String? _errorMessage;
  Timer? _debounce;
  String _sessionToken = const Uuid().v4(); // Token de sesión para autocompletado

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      // Usamos un debounce para no hacer una llamada a la API en cada tecla presionada
      if (_debounce?.isActive ?? false) _debounce!.cancel();
      _debounce = Timer(const Duration(milliseconds: 600), () {
        if (_controller.text.isNotEmpty) {
          _fetchPredictions(_controller.text);
        } else {
          setState(() => _predictions = []);
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Hace la llamada a la API de Google Place Autocomplete
  Future<void> _fetchPredictions(String input) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final apiKey = AppConfig.googlePlacesApiKey;
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$input&key=$apiKey&sessiontoken=$_sessionToken&components=country:co');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          setState(() {
            _predictions = (data['predictions'] as List)
                .map((p) => PlacePrediction.fromJson(p))
                .toList();
          });
        } else {
          // ¡AQUÍ CAPTURAREMOS EL ERROR REAL DE GOOGLE!
          setState(() {
            _errorMessage = data['error_message'] ?? data['status'];
          });
        }
      } else {
        setState(() => _errorMessage = "Error de red: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Error: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Obtiene los detalles (lat/lng) de un lugar seleccionado
  Future<void> _getPlaceDetails(String placeId) async {
    final apiKey = AppConfig.googlePlacesApiKey;
    final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey&sessiontoken=$_sessionToken&fields=geometry,name,formatted_address');
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final location = data['result']['geometry']['location'];
          final result = {
            'name': data['result']['formatted_address'] ?? data['result']['name'],
            'lat': location['lat'],
            'lng': location['lng'],
          };
          if (mounted) Navigator.pop(context, result);
        } else {
           setState(() => _errorMessage = data['error_message'] ?? data['status']);
        }
      } else {
         setState(() => _errorMessage = "Error de red: ${response.statusCode}");
      }
    } catch (e) {
       setState(() => _errorMessage = "Error: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buscar Lugar")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Escribe una dirección o nombre del lugar',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.search_normal_1),
                suffixIcon: _isLoading ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ) : null,
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text("Error: $_errorMessage", style: const TextStyle(color: Colors.red)),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _predictions.length,
                itemBuilder: (context, index) {
                  final prediction = _predictions[index];
                  return ListTile(
                    leading: const Icon(Iconsax.location),
                    title: Text(prediction.description),
                    onTap: () {
                      _getPlaceDetails(prediction.placeId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}