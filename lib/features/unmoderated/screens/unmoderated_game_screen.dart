import 'package:flutter/material.dart';
import '../../../shared/widgets/tambola_ticket_card.dart';
import '../models/unmoderated_ticket_model.dart';
import '../services/unmoderated_database_service.dart';

class UnmoderatedGameScreen extends StatefulWidget {
  final List<UnmoderatedTicket> tickets;

  const UnmoderatedGameScreen({
    super.key,
    required this.tickets,
  });

  @override
  State<UnmoderatedGameScreen> createState() => _UnmoderatedGameScreenState();
}

class _UnmoderatedGameScreenState extends State<UnmoderatedGameScreen> {
  // Store marked numbers for each ticket index
  late Map<int, Set<int>> _ticketMarks;

  @override
  void initState() {
    super.initState();
    _ticketMarks = {};
    for (int i = 0; i < widget.tickets.length; i++) {
        _ticketMarks[i] = widget.tickets[i].markedNumbers.toSet();
    }
  }

  Future<void> _toggleMark(int ticketIndex, int number) async {
    final marks = _ticketMarks[ticketIndex]!;
    
    // Optimistic update
    setState(() {
      if (marks.contains(number)) {
        marks.remove(number);
      } else {
        marks.add(number);
      }
    });

    // Save to DB
    await UnmoderatedDatabaseService().updateUnmoderatedTicketMarks(
        widget.tickets[ticketIndex].id, 
        marks.toList()
    );
  }

  void _resetTicket(int ticketIndex) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Ticket?'),
        content: const Text('This will clear all marked numbers on this ticket.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                _ticketMarks[ticketIndex]?.clear();
              });
              
              await UnmoderatedDatabaseService().updateUnmoderatedTicketMarks(
                widget.tickets[ticketIndex].id, 
                []
              );
              
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Tickets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetAllTickets,
            tooltip: 'Reset ALL tickets',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber[100],
            width: double.infinity,
            child: const Text(
              '⚠️ Unmoderated Game: You verify your own wins.',
              style: TextStyle(color: Colors.brown, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.tickets.length,
              separatorBuilder: (context, index) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ticket #${widget.tickets[index].id}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _resetTicket(index),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TambolaTicketCard(
                      ticketData: widget.tickets[index].grid,
                      markedNumbers: _ticketMarks[index]!,
                      onNumberTap: (number) => _toggleMark(index, number),
                      // Remove internal label since we added a header
                      ticketLabel: null, 
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _resetAllTickets() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Tickets?'),
        content: const Text('This will clear numbers on ALL tickets.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              setState(() {
                for (var key in _ticketMarks.keys) {
                  _ticketMarks[key]?.clear();
                }
              });
              
              // Update all in DB
               for (int i = 0; i < widget.tickets.length; i++) {
                   await UnmoderatedDatabaseService().updateUnmoderatedTicketMarks(
                    widget.tickets[i].id, 
                    []
                  );
               }
              
              if (!context.mounted) return;
              Navigator.pop(context);
            },
            child: const Text('RESET ALL'),
          ),
        ],
      ),
    );
  }
}
