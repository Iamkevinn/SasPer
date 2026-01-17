// lib/screens/icon_picker_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

class IconPickerScreen extends StatefulWidget {
  final IconData? currentIcon;

  const IconPickerScreen({super.key, this.currentIcon});

  @override
  State<IconPickerScreen> createState() => _IconPickerScreenState();
}

class _IconPickerScreenState extends State<IconPickerScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'Todos';
  
  // OPTIMIZACIÓN: Lista limitada de iconos más comunes
  static const Map<String, List<Map<String, dynamic>>> _iconsByCategory = {
    'Finanzas': [
      {'icon': Iconsax.wallet, 'name': 'Billetera'},
      {'icon': Iconsax.money, 'name': 'Dinero'},
      {'icon': Iconsax.card, 'name': 'Tarjeta'},
      {'icon': Iconsax.bank, 'name': 'Banco'},
      {'icon': Iconsax.chart, 'name': 'Gráfico'},
      {'icon': Iconsax.coin, 'name': 'Moneda'},
      {'icon': Iconsax.dollar_circle, 'name': 'Dólar'},
      {'icon': Iconsax.receipt, 'name': 'Recibo'},
      {'icon': Iconsax.empty_wallet, 'name': 'Cartera vacía'},
      {'icon': Iconsax.strongbox, 'name': 'Caja fuerte'},
    ],
    'Comida': [
      {'icon': Iconsax.coffee, 'name': 'Café'},
      {'icon': Icons.restaurant, 'name': 'Restaurante'},
      {'icon': Icons.local_pizza, 'name': 'Pizza'},
      {'icon': Icons.local_cafe, 'name': 'Cafetería'},
      {'icon': Icons.fastfood, 'name': 'Comida rápida'},
      {'icon': Icons.dinner_dining, 'name': 'Cena'},
      {'icon': Icons.lunch_dining, 'name': 'Almuerzo'},
      {'icon': Icons.breakfast_dining, 'name': 'Desayuno'},
      {'icon': Icons.icecream, 'name': 'Helado'},
      {'icon': Icons.cake, 'name': 'Postre'},
    ],
    'Transporte': [
      {'icon': Iconsax.car, 'name': 'Auto'},
      {'icon': Iconsax.bus, 'name': 'Bus'},
      {'icon': Icons.directions_subway, 'name': 'Metro'},
      {'icon': Icons.directions_bike, 'name': 'Bicicleta'},
      {'icon': Icons.local_taxi, 'name': 'Taxi'},
      {'icon': Icons.flight, 'name': 'Avión'},
      {'icon': Icons.directions_walk, 'name': 'Caminar'},
      {'icon': Icons.train, 'name': 'Tren'},
      {'icon': Icons.motorcycle, 'name': 'Moto'},
      {'icon': Icons.local_shipping, 'name': 'Camión'},
    ],
    'Compras': [
      {'icon': Iconsax.shopping_cart, 'name': 'Carrito'},
      {'icon': Iconsax.bag, 'name': 'Bolsa'},
      {'icon': Icons.shopping_bag, 'name': 'Compras'},
      {'icon': Icons.store, 'name': 'Tienda'},
      {'icon': Icons.local_mall, 'name': 'Centro comercial'},
      {'icon': Icons.checkroom, 'name': 'Ropa'},
      {'icon': Icons.watch, 'name': 'Accesorios'},
      {'icon': Iconsax.gift, 'name': 'Regalo'},
      {'icon': Icons.local_grocery_store, 'name': 'Supermercado'},
      {'icon': Icons.local_pharmacy, 'name': 'Farmacia'},
    ],
    'Entretenimiento': [
      {'icon': Iconsax.game, 'name': 'Juegos'},
      {'icon': Icons.movie, 'name': 'Cine'},
      {'icon': Icons.sports_esports, 'name': 'Videojuegos'},
      {'icon': Icons.music_note, 'name': 'Música'},
      {'icon': Icons.theater_comedy, 'name': 'Teatro'},
      {'icon': Icons.sports_soccer, 'name': 'Deportes'},
      {'icon': Icons.headphones, 'name': 'Auriculares'},
      {'icon': Icons.tv, 'name': 'TV'},
      {'icon': Icons.casino, 'name': 'Casino'},
      {'icon': Icons.celebration, 'name': 'Fiesta'},
    ],
    'Hogar': [
      {'icon': Iconsax.home, 'name': 'Casa'},
      {'icon': Icons.bed, 'name': 'Dormitorio'},
      {'icon': Icons.chair, 'name': 'Muebles'},
      {'icon': Icons.kitchen, 'name': 'Cocina'},
      {'icon': Icons.bathtub, 'name': 'Baño'},
      {'icon': Icons.weekend, 'name': 'Sofá'},
      {'icon': Icons.lightbulb, 'name': 'Luz'},
      {'icon': Icons.water_drop, 'name': 'Agua'},
      {'icon': Icons.build, 'name': 'Herramientas'},
      {'icon': Icons.cleaning_services, 'name': 'Limpieza'},
    ],
    'Salud': [
      {'icon': Iconsax.health, 'name': 'Salud'},
      {'icon': Icons.medical_services, 'name': 'Medicina'},
      {'icon': Icons.fitness_center, 'name': 'Gimnasio'},
      {'icon': Icons.favorite, 'name': 'Corazón'},
      {'icon': Icons.healing, 'name': 'Cura'},
      {'icon': Icons.spa, 'name': 'Spa'},
      {'icon': Icons.psychology, 'name': 'Mental'},
      {'icon': Icons.self_improvement, 'name': 'Meditación'},
      {'icon': Icons.local_hospital, 'name': 'Hospital'},
      {'icon': Icons.medication, 'name': 'Medicamentos'},
    ],
    'Educación': [
      {'icon': Iconsax.book, 'name': 'Libro'},
      {'icon': Icons.school, 'name': 'Escuela'},
      {'icon': Icons.menu_book, 'name': 'Lectura'},
      {'icon': Icons.science, 'name': 'Ciencia'},
      {'icon': Icons.calculate, 'name': 'Matemáticas'},
      {'icon': Icons.language, 'name': 'Idiomas'},
      {'icon': Icons.draw, 'name': 'Arte'},
      {'icon': Icons.computer, 'name': 'Computación'},
      {'icon': Icons.library_books, 'name': 'Biblioteca'},
      {'icon': Icons.backpack, 'name': 'Mochila'},
    ],
    'Tecnología': [
      {'icon': Iconsax.mobile, 'name': 'Móvil'},
      {'icon': Icons.laptop, 'name': 'Laptop'},
      {'icon': Icons.tablet, 'name': 'Tablet'},
      {'icon': Icons.watch, 'name': 'Reloj'},
      {'icon': Icons.headset, 'name': 'Auriculares'},
      {'icon': Icons.camera, 'name': 'Cámara'},
      {'icon': Icons.wifi, 'name': 'Internet'},
      {'icon': Icons.bluetooth, 'name': 'Bluetooth'},
      {'icon': Icons.devices, 'name': 'Dispositivos'},
      {'icon': Icons.print, 'name': 'Impresora'},
    ],
    'Otros': [
      {'icon': Iconsax.category, 'name': 'Categoría'},
      {'icon': Icons.star, 'name': 'Estrella'},
      {'icon': Icons.pets, 'name': 'Mascotas'},
      {'icon': Icons.child_care, 'name': 'Niños'},
      {'icon': Icons.elderly, 'name': 'Adultos'},
      {'icon': Icons.diamond, 'name': 'Premium'},
      {'icon': Icons.eco, 'name': 'Ecología'},
      {'icon': Icons.question_mark, 'name': 'Otro'},
      {'icon': Icons.more_horiz, 'name': 'Más'},
      {'icon': Icons.all_inclusive, 'name': 'Todo'},
    ],
  };

  List<Map<String, dynamic>> get _filteredIcons {
    List<Map<String, dynamic>> icons = [];
    
    // Filtrar por categoría
    if (_selectedCategory == 'Todos') {
      _iconsByCategory.values.forEach((categoryIcons) {
        icons.addAll(categoryIcons);
      });
    } else {
      icons = _iconsByCategory[_selectedCategory] ?? [];
    }
    
    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      icons = icons.where((iconData) {
        return iconData['name']
            .toString()
            .toLowerCase()
            .contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return icons;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        title: Text(
          'Seleccionar Icono',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Buscar icono...',
                prefixIcon: const Icon(Iconsax.search_normal),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              style: GoogleFonts.poppins(),
            ),
          ),

          // Categorías (scroll horizontal)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('Todos', colorScheme),
                ..._iconsByCategory.keys.map(
                  (category) => _buildCategoryChip(category, colorScheme),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Grid de iconos - OPTIMIZADO con GridView.builder
          Expanded(
            child: _filteredIcons.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Iconsax.search_normal,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No se encontraron iconos',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1,
                    ),
                    // CRÍTICO: Solo construye los iconos visibles
                    itemCount: _filteredIcons.length,
                    itemBuilder: (context, index) {
                      final iconData = _filteredIcons[index];
                      final isSelected = widget.currentIcon?.codePoint == 
                                        iconData['icon'].codePoint;
                      
                      return _buildIconButton(
                        iconData['icon'],
                        iconData['name'],
                        isSelected,
                        colorScheme,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, ColorScheme colorScheme) {
    final isSelected = _selectedCategory == category;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          category,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : colorScheme.onSurface,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _selectedCategory = category);
        },
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary,
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    String name,
    bool isSelected,
    ColorScheme colorScheme,
  ) {
    return Material(
      color: isSelected
          ? colorScheme.primaryContainer
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.pop(context, icon),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                name,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}