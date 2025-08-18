// lib/widgets/dashboard/active_challenges_widget.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/screens/challenges_screen.dart';

// Convertido a StatefulWidget para gestionar su propio ciclo de vida de datos.
class ActiveChallengesWidget extends StatefulWidget {
  const ActiveChallengesWidget({super.key});

  @override
  State<ActiveChallengesWidget> createState() => _ActiveChallengesWidgetState();
}

class _ActiveChallengesWidgetState extends State<ActiveChallengesWidget> {
  // El stream que alimentará la UI. Se inicializa después de la actualización.
  Stream<List<UserChallenge>>? _challengesStream;

  @override
  void initState() {
    super.initState();
    _initializeAndUpdateData();
  }

  /// Función que primero actualiza el estado de los retos en el backend,
  /// y LUEGO inicializa el stream para escuchar futuros cambios.
  Future<void> _initializeAndUpdateData() async {
    try {
      // 1. Esperamos a que la función de actualización termine.
      await ChallengeRepository.instance.checkUserChallengesStatus();
    } catch (e) {
      print("Error inicializando el widget de retos: $e");
    }

    // 2. Solo después de la actualización, nos suscribimos al stream.
    // Usamos 'mounted' para asegurarnos de que el widget todavía existe.
    if (mounted) {
      setState(() {
        _challengesStream = ChallengeRepository.instance.getUserChallengesStream();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si el stream aún no ha sido inicializado, no mostramos nada.
    if (_challengesStream == null) {
      return const SizedBox.shrink(); // O un pequeño loader si lo prefieres
    }

    return StreamBuilder<List<UserChallenge>>(
      stream: _challengesStream,
      builder: (context, snapshot) {
        // El resto de la lógica es la misma que ya teníamos.
        if (!snapshot.hasData) {
          return const SizedBox.shrink(); 
        }

        final activeChallenges = snapshot.data!.where((c) => c.status == 'active').toList();
        if (activeChallenges.isEmpty) {
          return const SizedBox.shrink();
        }

        // Si llegamos aquí, significa que hay al menos un reto activo para mostrar.
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16.0),
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias, // Para que el InkWell respete los bordes
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengesScreen())),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.cup, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Retos Activos',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      const Icon(Iconsax.arrow_right_3, size: 18),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Usamos un Divider para separar el título de la lista de retos
                  Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  
                  // Creamos la lista de retos con la nueva lógica visual
                  ...activeChallenges.map((uc) => _buildChallengeRow(context, uc)).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Construye la fila para un reto individual, decidiendo si mostrar la racha o los días restantes.
  Widget _buildChallengeRow(BuildContext context, UserChallenge userChallenge) {
    final challenge = userChallenge.challengeDetails;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          // El título del reto ocupa el espacio disponible
          Expanded(
            child: Text(
              challenge.title,
              style: const TextStyle(fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis, // Evita que el texto se desborde
            ),
          ),
          const SizedBox(width: 16),

          // --- ¡LÓGICA MEJORADA AQUÍ! ---
          // Decidimos qué widget mostrar a la derecha.
          _buildStreakOrDaysLeftWidget(context, userChallenge),
        ],
      ),
    );
  }

  /// Widget que muestra la racha para retos diarios, o los días restantes para retos normales.
  Widget _buildStreakOrDaysLeftWidget(BuildContext context, UserChallenge userChallenge) {
    // Si el reto es de tipo diario (de racha)...
    if (userChallenge.challengeDetails.resetsDaily) {
      return Row(
        mainAxisSize: MainAxisSize.min, // Para que la fila no ocupe más espacio del necesario
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)), // Icono de fuego
          const SizedBox(width: 4),
          Text(
            userChallenge.currentStreak.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
    } 
    // Si es un reto normal...
    else {
      final daysLeft = userChallenge.endDate.difference(DateTime.now()).inDays;
      // Aseguramos que no muestre números negativos si la fecha ya pasó
      final displayDays = daysLeft >= 0 ? daysLeft : 0; 
      
      return Text(
        '$displayDays días',
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
  }
}