import 'package:flutter/material.dart';

import '../../../shared/widgets/tambola_ticket_card.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/local_database_service.dart';
import 'player_join_screen.dart';

class PlayerTicketScreen extends StatefulWidget {
  final String gameId;
  final String? initialTicketId;

  const PlayerTicketScreen({
    super.key,
    required this.gameId,
    this.initialTicketId,
  });

  @override
  State<PlayerTicketScreen> createState() => _PlayerTicketScreenState();
}

class _PlayerTicketScreenState extends State<PlayerTicketScreen> {
  List<List<List<int>>> _tickets = []; // List of ticket grids
  List<String> _ticketIds = []; // List of ticket IDs
  Map<int, Set<int>> _markedNumbersMap = {}; // Map index to marked set
  bool _isLoading = true;
  String _errorMessage = '';
  String? _assignedName;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    try {
      final user = AuthService().currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Pure Local Fetch Logic
      // Since PlayerJoinScreen handles pre-fetching and saving, we rely 100% on Local DB here.
      final ticketsDocs = await LocalDatabaseService().getTickets(widget.gameId);
      debugPrint('Loaded ${ticketsDocs.length} tickets from Local DB for game ${widget.gameId}');

      if (ticketsDocs.isEmpty) {
         setState(() {
          _errorMessage = 'No tickets found for this game';
          _isLoading = false;
        });
        return;
      }

      List<List<List<int>>> loadedTickets = [];
      List<String> loadedTicketIds = [];
      Map<int, Set<int>> savedMarks = {}; // Temporary map to hold loaded marks
      String? name;

      int index = 0;
      for (var ticketMap in ticketsDocs) {
        if (ticketMap.containsKey('grid')) {
          final gridData = ticketMap['grid'];
          if (gridData is Map) {
             List<List<int>> parsedGrid = [];
             for (int i = 0; i < 3; i++) {
               final rowKey = 'row$i';
               if (gridData.containsKey(rowKey)) {
                 final rawRow = gridData[rowKey];
                 if (rawRow is List) {
                   parsedGrid.add(List<int>.from(rawRow.map((e) => e as int)));
                 }
               }
             }
             if (parsedGrid.length == 3) {
               loadedTickets.add(parsedGrid);
               // Use 'ticketId' from local DB or 'id' from Firestore/reconstructed map
               String tid = ticketMap['ticketId'] ?? ticketMap['id'] ?? 'Unknown';
               loadedTicketIds.add(tid);
               
               // Restore marked numbers
               if (ticketMap['markedNumbers'] != null) {
                  final List<dynamic> marks = ticketMap['markedNumbers'];
                  savedMarks[index] = marks.map((e) => e as int).toSet();
               }

               name = ticketMap['name'] as String?;
               index++;
             }
          }
        }
      }

      setState(() {
        _tickets = loadedTickets;
        _ticketIds = loadedTicketIds;
        _assignedName = name;
        _isLoading = false;
        _markedNumbersMap = savedMarks;
        
        // Initialize marked sets for remaining if any (though loop handles it)
        for (int i = 0; i < _tickets.length; i++) {
          if (!_markedNumbersMap.containsKey(i)) {
             _markedNumbersMap[i] = {};
          }
        }
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error loading tickets: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleMark(int ticketIndex, int number) {
    setState(() {
      final set = _markedNumbersMap[ticketIndex] ?? {};
      if (set.contains(number)) {
        set.remove(number);
      } else {
        set.add(number);
      }
      _markedNumbersMap[ticketIndex] = set;
    });
    
    // Auto-save changes
    if (_ticketIds.length > ticketIndex) {
      final tid = _ticketIds[ticketIndex];
      final marks = _markedNumbersMap[ticketIndex]?.toList() ?? [];
      LocalDatabaseService().updateTicketMarkedNumbers(tid, marks);
    }
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
            onPressed: () {
              setState(() {
                _markedNumbersMap[ticketIndex]?.clear();
              });
              Navigator.pop(context);
            },
            child: const Text('RESET'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTicket() async {
    if (_tickets.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 tickets allowed per player.')),
      );
      return;
    }
    // Navigate back to join/scanner to add another
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PlayerJoinScreen(isAddingMore: true)),
    );

    if (result != null) {
      _fetchTickets();
    }
  }

  Future<void> _handleClaimWin() async {
    final user = AuthService().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in.')));
      return;
    }

    // 1. Check if any numbers are marked
    bool hasMarks = false;
    for (var set in _markedNumbersMap.values) {
      if (set.isNotEmpty) {
        hasMarks = true;
        break;
      }
    }

    if (!hasMarks) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No Numbers Marked'),
          content: const Text('Please mark the numbers on your ticket that match the called numbers before claiming.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    // 2. Confirm Claim
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim Win?'),
        content: const Text('Are you sure you have a winning pattern (Bingo, Line, etc.)? This will alert the host to check your tickets.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CLAIM', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );

    if (confirm != true) return;

    // 3. Prepare Data
    final Map<String, List<int>> markedData = {};
    for (int i = 0; i < _tickets.length; i++) {
      if (_ticketIds.length > i) {
        final tid = _ticketIds[i];
        final marks = _markedNumbersMap[i] ?? {};
        if (marks.isNotEmpty) {
           markedData[tid] = marks.toList();
        }
      }
    }

    // 4. Submit
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitting claim...')));
      
      await FirestoreService().submitWinClaim(
        gameId: widget.gameId,
        playerUid: user.uid,
        playerName: _assignedName ?? user.displayName ?? 'Unknown',
        markedData: markedData,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Claim Sent!'),
          content: const Text('The host has been notified. Please wait for them to verify your ticket.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting claim: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Tickets (${_tickets.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Ticket',
            onPressed: _addTicket,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleClaimWin,
        icon: const Icon(Icons.emoji_events),
        label: const Text('CLAIM WIN'),
        backgroundColor: Colors.amber,
        foregroundColor: Colors.black,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
          : ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: _tickets.length,
              separatorBuilder: (context, index) => const Divider(height: 48, thickness: 1),
              itemBuilder: (context, index) {
                final ticket = _tickets[index];
                final marked = _markedNumbersMap[index] ?? {};
                
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Ticket #${_ticketIds[index]}', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          )),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _resetTicket(index),
                            tooltip: 'Reset This Ticket',
                          ),
                        ],
                      ),
                      if (_assignedName != null && _assignedName != 'Unknown')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            'Assigned to: $_assignedName',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ),
                      TambolaTicketCard(
                        ticketData: ticket,
                        markedNumbers: marked,
                        onNumberTap: (num) => _toggleMark(index, num),
                        ticketLabel: 'Ticket #${_ticketIds[index]}',
                      ),
                    ],
                  );
              },
            ),
    );
  }
}
