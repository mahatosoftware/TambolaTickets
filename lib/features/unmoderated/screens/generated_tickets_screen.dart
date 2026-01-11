import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/unmoderated_database_service.dart';
import '../models/unmoderated_ticket_model.dart';
import 'unmoderated_game_screen.dart';

class GeneratedTicketsScreen extends StatefulWidget {
  const GeneratedTicketsScreen({super.key});

  @override
  State<GeneratedTicketsScreen> createState() => _GeneratedTicketsScreenState();
}

class _GeneratedTicketsScreenState extends State<GeneratedTicketsScreen> {
  // Map of SessionId -> List of Tickets
  Map<String, List<UnmoderatedTicket>> _sessions = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoading = true);
    final ticketMaps = await UnmoderatedDatabaseService().getAllUnmoderatedTickets();
    
    final allTickets = ticketMaps.map((m) => UnmoderatedTicket.fromMap(m)).toList();
    
    // Group by session
    final Map<String, List<UnmoderatedTicket>> sessions = {};
    for (var ticket in allTickets) {
      // Use sessionId if available, otherwise fallback to grouping by exact createdAt or just unique per ticket (legacy)
      // For legacy (null sessionId), let's group by createdAt (roughly same second) or just treat as individual.
      // Easiest fallback: use ticket.id as unique session if no sessionId.
      final key = ticket.sessionId ?? 'legacy_${ticket.createdAt.millisecondsSinceEpoch}';
      
      if (!sessions.containsKey(key)) {
        sessions[key] = [];
      }
      sessions[key]!.add(ticket);
    }
    
    // Sort logic? keys might not be sorted.
    // Let's keep them in the order they were inserted (which is descending by createdAt from DB query usually)
    // But map iteration order is insertion order in Dart.
    // DB query `getAllUnmoderatedTickets` sorts by created DESC. 
    // So the FIRST ticket encountered defines the order of the session roughly.
    
    setState(() {
      _sessions = sessions;
      _isLoading = false;
    });
  }

  Future<void> _deleteSession(String key, List<UnmoderatedTicket> tickets) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text('Delete ${tickets.length} tickets? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (tickets.first.sessionId != null) {
          // New style session delete
          await UnmoderatedDatabaseService().deleteUnmoderatedSession(tickets.first.sessionId!);
      } else {
          // Legacy: delete each ticket
          for(var t in tickets) {
             await UnmoderatedDatabaseService().deleteUnmoderatedTicket(t.id);
          }
      }
      _loadTickets();
    }
  }

  void _openSession(List<UnmoderatedTicket> tickets) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UnmoderatedGameScreen(tickets: tickets),
      ),
    ).then((_) => _loadTickets()); 
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All History?'),
        content: const Text('This will permanently delete ALL generated tickets.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE ALL'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await UnmoderatedDatabaseService().deleteAllUnmoderatedTickets();
      _loadTickets();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Convert map to list for display
    final sessionKeys = _sessions.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Tickets'),
        actions: [
          if (_sessions.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_forever_outlined),
              tooltip: 'Delete All',
              onPressed: _deleteAll,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(
                  child: Text(
                    'No tickets found',
                    style: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: sessionKeys.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final key = sessionKeys[index];
                    final tickets = _sessions[key]!;
                    final firstTicket = tickets.first;
                    
                    final dateStr = DateFormat('MMM d, yyyy h:mm a')
                        .format(firstTicket.createdAt);
                    
                    final totalMarked = tickets.fold<int>(0, (sum, t) => sum + t.markedNumbers.length);
                    final ticketCount = tickets.length;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: ListTile(
                        onTap: () => _openSession(tickets),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '$ticketCount',
                              style: const TextStyle(
                                color: Colors.blueAccent, 
                                fontWeight: FontWeight.bold,
                                fontSize: 20
                              )
                            ),
                          ),
                        ),
                        title: Text(
                          'Ticket #${firstTicket.id}', // Changed to display firstTicket.id
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('$dateStr\nMarked: $totalMarked numbers'), 
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.grey),
                          onPressed: () => _deleteSession(key, tickets),
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}
