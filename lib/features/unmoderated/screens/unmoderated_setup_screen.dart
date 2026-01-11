import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/utils/ticket_generator.dart';
import '../services/unmoderated_database_service.dart';
import '../models/unmoderated_ticket_model.dart';
import 'unmoderated_game_screen.dart';
import 'generated_tickets_screen.dart';

class UnmoderatedSetupScreen extends StatefulWidget {
  const UnmoderatedSetupScreen({super.key});

  @override
  State<UnmoderatedSetupScreen> createState() => _UnmoderatedSetupScreenState();
}

class _UnmoderatedSetupScreenState extends State<UnmoderatedSetupScreen> {
  int _ticketCount = 1;

  Future<void> _startGame() async {
    // Generate tickets
    final now = DateTime.now();
    final random = Random();
    final sessionId = now.millisecondsSinceEpoch.toString(); // Simple session ID
    
    List<UnmoderatedTicket> tickets = [];
    
    for (int i = 0; i < _ticketCount; i++) {
        final grid = TambolaTicketGenerator.generateTicket();
        String id;
        bool taken = true;
        
        // Generate unique alphanumeric ID
        do {
           id = _generateAlphanumericId(random, 6);
           taken = await UnmoderatedDatabaseService().isUnmoderatedTicketIdTaken(id);
        } while (taken);

        final ticket = UnmoderatedTicket(
          id: id, 
          sessionId: sessionId,
          createdAt: now, 
          grid: grid,
          markedNumbers: [],
        );
        
        tickets.add(ticket);
        await UnmoderatedDatabaseService().createUnmoderatedTicket(ticket.toMap());
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnmoderatedGameScreen(tickets: tickets),
      ),
    );
  }

  String _generateAlphanumericId(Random random, int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unmoderated Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.casino_rounded,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 24),
            const Text(
              'How many tickets do you need?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCountButton(
                  icon: Icons.remove,
                  onPressed: _ticketCount > 1
                      ? () => setState(() => _ticketCount--)
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    '$_ticketCount',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
                _buildCountButton(
                  icon: Icons.add,
                  onPressed: _ticketCount < 6 // Max 6 for simplicity
                      ? () => setState(() => _ticketCount++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Max 6 tickets for manual play',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
             ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const GeneratedTicketsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blueAccent,
                side: const BorderSide(color: Colors.blueAccent),
              ),
              child: const Text(
                'GENERATED TICKETS',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startGame,
              child: const Text(
                'START GAME',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCountButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onPressed == null ? Colors.grey[300] : Colors.blueAccent,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
        iconSize: 32,
      ),
    );
  }
}
