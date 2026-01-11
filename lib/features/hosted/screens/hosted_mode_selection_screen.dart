import 'package:flutter/material.dart';
import 'host_game_id_screen.dart';
import 'player_join_screen.dart';

class HostedModeSelectionScreen extends StatelessWidget {
  const HostedModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Role'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Who are you?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: _buildRoleCard(
                context,
                title: 'I am the Host',
                description: 'Create a game, distribute tickets and verify winners.',
                icon: Icons.admin_panel_settings_rounded,
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HostGameIdScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _buildRoleCard(
                context,
                title: 'I am a Player',
                description: 'Join a game using a code to get your tickets.',
                icon: Icons.person_rounded,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PlayerJoinScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 64,
                color: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
