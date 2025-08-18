// lib/screens/challenges_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/models/challenge_model.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final _repository = ChallengeRepository.instance;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Centro de Hábitos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mis Retos'),
              Tab(text: 'Disponibles'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUserChallenges(),
            _buildAvailableChallenges(),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailableChallenges() {
    return FutureBuilder<List<Challenge>>(
      future: _repository.getAvailableChallenges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay nuevos retos por ahora.'));
        }
        final challenges = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: challenges.length,
          itemBuilder: (context, index) {
            final challenge = challenges[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(challenge.description),
                trailing: ElevatedButton(
                  child: const Text('Aceptar'),
                  onPressed: () async {
                    await _repository.startChallenge(challenge);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Reto aceptado! Puedes verlo en "Mis Retos".'), backgroundColor: Colors.green),
                    );
                    setState(() {}); // Recarga la vista
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUserChallenges() {
    return StreamBuilder<List<UserChallenge>>(
      stream: _repository.getUserChallengesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Aún no has aceptado ningún reto.'));
        }
        final userChallenges = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userChallenges.length,
          itemBuilder: (context, index) {
            final userChallenge = userChallenges[index];
            final challenge = userChallenge.challengeDetails;
            final daysLeft = userChallenge.endDate.difference(DateTime.now()).inDays;

            Icon statusIcon;
            Color statusColor;
            String statusText = 'Activo - Quedan $daysLeft días';

            switch (userChallenge.status) {
              case 'completed':
                statusIcon = const Icon(Icons.check_circle, color: Colors.green);
                statusColor = Colors.green;
                statusText = '¡Completado!';
                break;
              case 'failed':
                statusIcon = const Icon(Icons.cancel, color: Colors.red);
                statusColor = Colors.red;
                statusText = 'Fallido';
                break;
              default: // active
                statusIcon = const Icon(Icons.hourglass_top, color: Colors.blue);
                statusColor = Colors.blue;
                break;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: statusIcon,
                title: Text(challenge.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(statusText, style: TextStyle(color: statusColor)),
                onTap: () {
                  if(userChallenge.status == 'completed') {
                    showDialog(context: context, builder: (_) => AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           SizedBox(
                            width: 150,
                            height: 150,
                            child: Lottie.asset('assets/animations/confetti_celebration.json'), 
                          ),
                        ],
                      ),
                    ));
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}