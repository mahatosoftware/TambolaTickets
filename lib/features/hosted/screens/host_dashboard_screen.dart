import 'package:flutter/material.dart';
import 'dart:math';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/utils/ticket_generator.dart';
import 'hosted_ticket_detail_screen.dart';

class HostDashboardScreen extends StatefulWidget {
  final int bulkCount;
  final String gameId;

  const HostDashboardScreen({
    super.key,
    required this.bulkCount,
    required this.gameId,
  });

  @override
  State<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends State<HostDashboardScreen> {
  // Mock Data
  int _singleTicketsSold = 0;
  int _bulkBundlesSold = 0;
  int _manualSingleSold = 0;
  int _manualBulkSold = 0;
  
  // List of generated player tickets (Mock)
  final List<Map<String, dynamic>> _playerTickets = [];

  @override
  void initState() {
    super.initState();
    // Save session immediately to register Game ID
    // Done in post frame to allow context usage for SnackBar if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _saveSession();
    });
  }

  Future<String?> _showNameInputDialog() async {
    String? playerName;
    await showDialog(
      context: context,
      builder: (context) {
        String input = '';
        return AlertDialog(
          title: const Text('Enter Player Name'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. Rahul',
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (val) {
              input = val;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            TextButton(
              onPressed: () {
                playerName = 'Anonymous';
                Navigator.pop(context);
              },
              child: const Text('ANONYMOUS'),
            ),
            TextButton(
              onPressed: () {
                playerName = input.trim().isEmpty ? 'Anonymous' : input.trim();
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    return playerName;
  }

  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _saveSession() async {
    try {
      await _firestoreService.saveGameSession(
        gameId: widget.gameId,
        digitalCount: _singleTicketsSold + (_bulkBundlesSold * widget.bulkCount),
        manualCount: _manualSingleSold + (_manualBulkSold * widget.bulkCount),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving session: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _generateTicketSuffix() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd =  Random(); 
    return String.fromCharCodes(Iterable.generate(
      3,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  String _generateUniqueTicketId() {
    String suffix;
    String id;
    bool exists;
    do {
      suffix = _generateTicketSuffix();
      id = '${widget.gameId}-$suffix';
      exists = _playerTickets.any((ticket) => ticket['id'] == id);
    } while (exists);
    return id;
  }

  Future<void> _addTicket({bool isBulk = false}) async {
    // Name prompt skipped for Digital tickets as preferred by user
    const name = 'Player';

    List<Map<String, dynamic>> newTickets = [];

    if (isBulk) {
      for(int i=0; i<widget.bulkCount; i++) {
          final id = _generateUniqueTicketId();
          final ticketData = TambolaTicketGenerator.generateTicket();
          final newTicket = {
          'id': id,
          'name': '$name (Bundle)',
          'isActive': true,
          'type': 'Digital',
          'ticketData': ticketData, // Store actual numbers
        };
          newTickets.add(newTicket);
      }
    } else {
      final id = _generateUniqueTicketId();
      final ticketData = TambolaTicketGenerator.generateTicket();
      final newTicket = {
        'id': id,
        'name': name,
        'isActive': true,
        'type': 'Digital',
        'ticketData': ticketData,
      };
      newTickets.add(newTicket);
    }

    // Local updates removed since StreamBuilder handles UI
    // Counter updates removed as they are now derived from stream

    try {
      // Save all new tickets
      for (var ticket in newTickets) {
        await _firestoreService.saveTicket(widget.gameId, ticket);
      }
      await _saveSession();

      if (mounted && !isBulk && newTickets.isNotEmpty) {
          final t = newTickets.first;
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (context) => HostedTicketDetailScreen(
                 ticketId: t['id'],
                 playerName: t['name'] ?? 'Unknown',
                 initialActiveStatus: t['isActive'] ?? true,
                 ticketData: t['ticketData'], // Data is available directly here as List<List<int>>
               ),
            ),
          );
      }
    } catch (e) {
        if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving ticket: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addManualTicket({bool isBulk = false}) async {
    final name = await _showNameInputDialog();
    if (name == null) return;

    List<Map<String, dynamic>> newTickets = [];

    if (isBulk) {
      // Manual Bundle Logic
      for (int i = 0; i < widget.bulkCount; i++) {
        final id = _generateUniqueTicketId();
        final ticketData = TambolaTicketGenerator.generateTicket();

        final newTicket = {
          'id': id,
          'name': '$name (Bundle)',
          'isActive': true,
          'type': 'Paper',
          'ticketData': ticketData,
        };
        newTickets.add(newTicket);
      }
    } else {
      // Manual Single Logic
      final id = _generateUniqueTicketId();
      // Manual tickets do not generate actual numbers
      final ticketData = <List<int>>[];

      final newTicket = {
        'id': id,
        'name': name,
        'isActive': true,
        'type': 'Paper',
        'ticketData': ticketData,
      };
      newTickets.add(newTicket);
    }

    // Local updates removed since StreamBuilder handles UI

    try {
      for (var ticket in newTickets) {
        await _firestoreService.saveTicket(widget.gameId, ticket);
      }
      await _saveSession();
      
      if (mounted && !isBulk && newTickets.isNotEmpty) {
          final t = newTickets.first;
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (context) => HostedTicketDetailScreen(
                 ticketId: t['id'],
                 playerName: t['name'] ?? 'Unknown',
                 initialActiveStatus: t['isActive'] ?? true,
                 ticketData: t['ticketData'], 
               ),
            ),
          );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving ticket: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Host: ${widget.gameId}'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _firestoreService.getGameTicketsStream(widget.gameId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final tickets = snapshot.data ?? [];
          
          // Calculate counts for stats
          int digital = 0;
          int manual = 0;

          // Note: Since we are not storing "isBulk" explicitly in the simple map for stats calculation easily 
          // without iterating, we iterate. 
          // However, our previous logic relied on local counters.
          // To be accurate with the DB, we count based on 'type'.
          
          for (var t in tickets) {
            final isManual = (t['type'] as String? ?? '').toLowerCase().contains('paper');
             if (isManual) {
               manual++;
             } else {
               digital++;
             }
          }
          
          // We can update the session stats lazily or relies on the _saveSession from actions
          
          return Column(
            children: [
              // Revenue Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                color: Theme.of(context).primaryColor,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                     Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                         _buildStatItem('Digital', '$digital'),
                         _buildStatItem('Manual', '$manual'),
                      ],
                    )
                  ],
                ),
              ),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Actions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            label: 'Issue Single Digital Ticket',
                            icon: Icons.confirmation_number_outlined,
                            color: Colors.blue,
                            onTap: () => _addTicket(isBulk: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            context,
                            label: 'Issue Single Paper Ticket',
                            icon: Icons.note_add_outlined,
                            color: Colors.orange,
                            onTap: () => _addManualTicket(isBulk: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Active Tickets',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (tickets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('No tickets issued yet.')),
                      )
                    else
                      ...tickets.map((data) {
                        final isAssigned = data['claimedAt'] != null || data['playerId'] != null;
                        
                        return Card(
                          color: isAssigned ? Colors.teal.shade50 : null,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAssigned ? Colors.teal.shade100 : Theme.of(context).primaryColorLight,
                              foregroundColor: isAssigned ? Colors.teal.shade900 : null,
                              child: Text(
                                (data['id'] as String).length > 3 ? (data['id'] as String).substring((data['id'] as String).length - 3) : data['id'], 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                                data['name'] ?? 'Unknown',
                                style: TextStyle(
                                    fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
                                    color: isAssigned ? Colors.teal.shade900 : null
                                ),
                            ),
                            subtitle: Text(
                                '${data['id']} • ${data['type']}${isAssigned ? ' • Player #${data['playerId']}' : ''}',
                                style: TextStyle(color: isAssigned ? Colors.teal.shade700 : null),
                            ),
                            trailing: Switch(
                              value: data['isActive'] ?? true,
                              activeColor: isAssigned ? Colors.teal : null,
                              onChanged: (val) {
                                // Update via Firestore
                                _firestoreService.updateTicketStatus(widget.gameId, data['id'], val);
                              },
                            ),
                            onTap: () {
                              // Reconstruct data from 'grid' map or use 'ticketData'
                              List<List<int>> ticketGrid = [];
                              if (data['grid'] != null) {
                                final gridMap = data['grid'] as Map<String, dynamic>;
                                final r0 = List<int>.from(gridMap['row0'] ?? []);
                                final r1 = List<int>.from(gridMap['row1'] ?? []);
                                final r2 = List<int>.from(gridMap['row2'] ?? []);
                                
                                if (r0.isNotEmpty) {
                                  ticketGrid = [r0, r1, r2];
                                }
                              } else if (data['ticketData'] != null) {
                                final list = data['ticketData'] as List;
                                if (list.isNotEmpty) {
                                  ticketGrid = list.map((e) => List<int>.from(e)).toList();
                                }
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => HostedTicketDetailScreen(
                                    ticketId: data['id'],
                                    playerName: data['name'] ?? 'Unknown',
                                    initialActiveStatus: data['isActive'] ?? true,
                                    ticketData: ticketGrid,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          );
        } // builder
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label, 
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color, 
                  fontWeight: FontWeight.bold
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
