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

class _IconPickerScreenState extends State<IconPickerScreen> 
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  
  String _searchQuery = '';
  IconData? _selectedIcon;

  // Mapas de iconos categorizados
  final Map<String, List<MapEntry<String, IconData>>> _categorizedIcons = {
    'Finanzas': [
      MapEntry('Dinero', Icons.attach_money),
      MapEntry('Tarjeta', Icons.credit_card),
      MapEntry('Billetera', Icons.account_balance_wallet),
      MapEntry('Banco', Icons.account_balance),
      MapEntry('Ahorro', Icons.savings),
      MapEntry('Pago', Icons.payment),
      MapEntry('Gráfica', Icons.show_chart),
      MapEntry('Tendencia', Icons.trending_up),
      MapEntry('Inversión', Icons.monetization_on),
      MapEntry('Monedas', Iconsax.dollar_circle),
      MapEntry('Tarjeta2', Iconsax.card),
      MapEntry('Billetera2', Iconsax.wallet),
      MapEntry('Gráfica2', Iconsax.chart),
      MapEntry('Tendencia2', Iconsax.trend_up),
    ],
    'Comida': [
      MapEntry('Restaurante', Icons.restaurant),
      MapEntry('Café', Icons.local_cafe),
      MapEntry('Pizza', Icons.local_pizza),
      MapEntry('Comida Rápida', Icons.fastfood),
      MapEntry('Bar', Icons.local_bar),
      MapEntry('Postre', Icons.cake),
      MapEntry('Café2', Iconsax.coffee),
    ],
    'Transporte': [
      MapEntry('Carro', Icons.directions_car),
      MapEntry('Bus', Icons.directions_bus),
      MapEntry('Tren', Icons.train),
      MapEntry('Avión', Icons.flight),
      MapEntry('Bici', Icons.directions_bike),
      MapEntry('Moto', Icons.two_wheeler),
      MapEntry('Taxi', Icons.local_taxi),
      MapEntry('Metro', Icons.subway),
      MapEntry('Carro2', Iconsax.car),
      MapEntry('Gas', Iconsax.gas_station),
    ],
    'Hogar': [
      MapEntry('Casa', Icons.home),
      MapEntry('Cama', Icons.bed),
      MapEntry('Baño', Icons.bathtub),
      MapEntry('Cocina', Icons.kitchen),
      MapEntry('Sofá', Icons.weekend),
      MapEntry('Luz', Icons.lightbulb),
      MapEntry('Wifi', Icons.wifi),
      MapEntry('Herramientas', Icons.build),
      MapEntry('Casa2', Iconsax.house),
      MapEntry('Lámpara', Iconsax.lamp),
    ],
    'Compras': [
      MapEntry('Carrito', Icons.shopping_cart),
      MapEntry('Bolsa', Icons.shopping_bag),
      MapEntry('Tienda', Icons.store),
      MapEntry('Moda', Icons.checkroom),
      MapEntry('Etiqueta', Icons.local_offer),
      MapEntry('Carrito2', Iconsax.shopping_cart),
      MapEntry('Bolsa2', Iconsax.bag),
      MapEntry('Tienda2', Iconsax.shop),
    ],
    'Salud': [
      MapEntry('Hospital', Icons.local_hospital),
      MapEntry('Farmacia', Icons.local_pharmacy),
      MapEntry('Corazón', Icons.favorite),
      MapEntry('Fitness', Icons.fitness_center),
      MapEntry('Médico', Icons.medical_services),
      MapEntry('Salud2', Iconsax.health),
      MapEntry('Corazón2', Iconsax.heart),
    ],
    'Educación': [
      MapEntry('Escuela', Icons.school),
      MapEntry('Libro', Icons.menu_book),
      MapEntry('Graduación', Icons.school),
      MapEntry('Mochila', Icons.backpack),
      MapEntry('Lápiz', Icons.edit),
      MapEntry('Libro2', Iconsax.book),
      MapEntry('Educación', Iconsax.teacher),
    ],
    'Entretenimiento': [
      MapEntry('Película', Icons.movie),
      MapEntry('Música', Icons.music_note),
      MapEntry('Juego', Icons.sports_esports),
      MapEntry('TV', Icons.tv),
      MapEntry('Cámara', Icons.camera_alt),
      MapEntry('Deporte', Icons.sports_soccer),
      MapEntry('Juego2', Iconsax.game),
      MapEntry('Música2', Iconsax.music),
    ],
    'Servicios': [
      MapEntry('Teléfono', Icons.phone),
      MapEntry('Internet', Icons.language),
      MapEntry('Correo', Icons.email),
      MapEntry('Nube', Icons.cloud),
      MapEntry('Seguridad', Icons.security),
      MapEntry('Limpieza', Icons.cleaning_services),
      MapEntry('Móvil', Iconsax.mobile),
      MapEntry('Global', Iconsax.global),
    ],
    'Trabajo': [
      MapEntry('Trabajo', Icons.work),
      MapEntry('Maleta', Icons.business_center),
      MapEntry('Computadora', Icons.computer),
      MapEntry('Escritorio', Icons.desk),
      MapEntry('Calendario', Icons.calendar_today),
      MapEntry('Reloj', Icons.access_time),
      MapEntry('Briefcase', Iconsax.briefcase),
      MapEntry('Código', Iconsax.code),
    ],
    'Otros': [
      MapEntry('Regalo', Icons.card_giftcard),
      MapEntry('Mascota', Icons.pets),
      MapEntry('Planta', Icons.local_florist),
      MapEntry('Bebé', Icons.child_care),
      MapEntry('Viaje', Icons.luggage),
      MapEntry('Evento', Icons.event),
      MapEntry('Regalo2', Iconsax.gift),
      MapEntry('Mascota2', Iconsax.pet),
      MapEntry('Estrella', Iconsax.star),
      MapEntry('Categoría', Iconsax.category),
    ],
  };

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.currentIcon;
    _tabController = TabController(
      length: _categorizedIcons.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, IconData>> _getFilteredIcons(String category) {
    final icons = _categorizedIcons[category] ?? [];
    if (_searchQuery.isEmpty) return icons;

    return icons.where((entry) {
      return entry.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  List<MapEntry<String, IconData>> _getAllFilteredIcons() {
    if (_searchQuery.isEmpty) return [];
    
    final allIcons = <MapEntry<String, IconData>>[];
    _categorizedIcons.values.forEach((icons) {
      allIcons.addAll(icons);
    });

    return allIcons.where((entry) {
      return entry.key.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (_selectedIcon != null)
                TextButton.icon(
                  onPressed: () => Navigator.pop(context, _selectedIcon),
                  icon: const Icon(Icons.check_circle),
                  label: Text(
                    'Seleccionar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Elegir Icono',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
          ),

          // Barra de búsqueda
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar icono...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ),

          // Icono seleccionado preview
          if (_selectedIcon != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _selectedIcon,
                        size: 32,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Icono Seleccionado',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Presiona "Seleccionar" para confirmar',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Resultados de búsqueda o tabs
          if (_searchQuery.isNotEmpty)
            _buildSearchResults()
          else
            ...[
              // Tabs
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: colorScheme.primary,
                    ),
                    labelColor: colorScheme.onPrimary,
                    unselectedLabelColor: colorScheme.onSurfaceVariant,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: _categorizedIcons.keys.map((category) {
                      return Tab(text: category);
                    }).toList(),
                  ),
                ),
              ),

              // Grid de iconos
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: _categorizedIcons.keys.map((category) {
                    final icons = _getFilteredIcons(category);
                    return _buildIconGrid(icons);
                  }).toList(),
                ),
              ),
            ],
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final results = _getAllFilteredIcons();

    if (results.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
              const SizedBox(height: 16),
              Text(
                'Sin resultados para: "$_searchQuery"',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Intenta con otra palabra',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${results.length} resultados',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildIconGrid(results),
          ],
        ),
      ),
    );
  }

  Widget _buildIconGrid(List<MapEntry<String, IconData>> icons) {
    if (icons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Text(
            'No hay iconos en esta categoría',
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: icons.length,
      itemBuilder: (context, index) {
        final entry = icons[index];
        final isSelected = _selectedIcon?.codePoint == entry.value.codePoint &&
                          _selectedIcon?.fontFamily == entry.value.fontFamily;

        return _IconTile(
          icon: entry.value,
          label: entry.key,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedIcon = entry.value;
            });
          },
        );
      },
    );
  }
}

// Widget de icono individual
class _IconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _IconTile({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isSelected
          ? colorScheme.primary.withOpacity(0.15)
          : colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
                size: 28,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Delegate para el header sticky
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}