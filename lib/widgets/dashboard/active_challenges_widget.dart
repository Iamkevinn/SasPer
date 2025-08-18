// lib/widgets/dashboard/active_challenges_widget.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/screens/challenges_screen.dart';

class ActiveChallengesWidget extends StatelessWidget {
  const ActiveChallengesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<UserChallenge>>(
      stream: ChallengeRepository.instance.getUserChallengesStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Si no hay datos, no mostramos nada para no ocupar espacio
          return const SizedBox.shrink(); 
        }

        final activeChallenges = snapshot.data!.where((c) => c.status == 'active').toList();

        if (activeChallenges.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChallengesScreen())),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Iconsax.cup, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Retos Activos',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...activeChallenges.map((uc) => _buildChallengeRow(uc)).toList(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChallengeRow(UserChallenge userChallenge) {
    final daysLeft = userChallenge.endDate.difference(DateTime.now()).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(child: Text(userChallenge.challengeDetails.title)),
          Text(
            '$daysLeft días restantes',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}