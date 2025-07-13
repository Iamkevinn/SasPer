import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class ProjectionCard extends StatefulWidget {
  final String accountId;

  const ProjectionCard({super.key, required this.accountId});

  @override
  State<ProjectionCard> createState() => _ProjectionCardState();
}

class _ProjectionCardState extends State<ProjectionCard> {
  late Future<double> _projectionFuture;

  @override
  void initState() {
    super.initState();
    _projectionFuture = _fetchProjection();
  }

  Future<double> _fetchProjection() async {
    final response = await Supabase.instance.client.rpc(
      'get_burn_rate_projection',
      params: {'account_id_param': widget.accountId},
    ) as List<dynamic>;

    developer.log("Response from RPC: $response", name: 'ProjectionCard');

    if (response.isEmpty) {
      return 0.0; // No hay datos, asumimos 0 días.
    }
    return (response.first['days_left'] as num).toDouble();
  }

  // Función para formatear los días en un texto legible
  String _formatDays(double days) {
    if (days == -1) {
      return "Fondos estables"; // Código para "infinito"
    }
    if (days <= 0) {
      return "Fondos agotados";
    }
    if (days < 30) {
      return "${days.toStringAsFixed(0)} días";
    }
    final months = days / 30;
    if (months < 12) {
      return "${months.toStringAsFixed(1)} meses";
    }
    final years = months / 12;
    return "${years.toStringAsFixed(1)} años";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _projectionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmer();
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == 0) {
          // No mostramos nada si hay error, no hay datos o la proyección es 0.
          return const SizedBox.shrink(); 
        }

        final daysLeft = snapshot.data!;
        final projectionText = _formatDays(daysLeft);

        // Si los fondos son estables, usamos un color diferente.
        final isStable = daysLeft == -1;
        final color = isStable ? Colors.blue.shade300 : Colors.orange.shade400;

        return Container(
          margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(isStable ? Iconsax.shield_tick : Iconsax.timer_1, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isStable ? projectionText : "Proyección: $projectionText restantes",
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}