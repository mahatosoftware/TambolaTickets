import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/local_database_service.dart';
import 'player_ticket_screen.dart';

class PlayerJoinScreen extends StatefulWidget {
  final bool isAddingMore;

  const PlayerJoinScreen({super.key, this.isAddingMore = false});

  @override
  State<PlayerJoinScreen> createState() => _PlayerJoinScreenState();
}

class _PlayerJoinScreenState extends State<PlayerJoinScreen> {
  final TextEditingController _codeController = TextEditingController();

  bool _isJoining = false;

  List<Map<String, dynamic>> _recentGames = [];

  @override
  void initState() {
    super.initState();
    _loadRecentGames();
  }

  Future<void> _loadRecentGames() async {
    final games = await LocalDatabaseService().getRecentJoinedGames();
    if (mounted) {
      setState(() {
        _recentGames = games;
      });
    }
  }

  Future<void> _processTicket(String code) async {
    if (_isJoining) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final user = AuthService().currentUser;
      if (user != null) {
        // 1. Claim Ticket
        await FirestoreService().claimTicket(code, user.uid);
        if (!mounted) return;

        // 2. Parse gameId
        final lastHyphen = code.lastIndexOf('-');
        final gameId = (lastHyphen != -1) ? code.substring(0, lastHyphen) : code;

        // Save session & history immediately
        await LocalDatabaseService().setCurrentGameId(gameId);
        await LocalDatabaseService().saveJoinedGame(gameId);

        // 3. Pre-fetch and Save Ticket Locally
        try {
          final ticketData = await FirestoreService().getTicket(code);
          if (ticketData != null) {
            await LocalDatabaseService().saveTicket(gameId, ticketData);
            debugPrint('Pre-fetched and saved ticket $code locally.');
          }
        } catch (e) {
          debugPrint('Warning: Failed to pre-fetch ticket: $e');
        }

        if (!mounted) return;

        if (widget.isAddingMore) {
          Navigator.pop(context, code);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerTicketScreen(
                gameId: gameId,
                initialTicketId: code,
              ),
            ),
          );
        }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in first')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _joinGame() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isJoining = true;
    });

    try {
      final user = AuthService().currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in first')));
        return;
      }

      if (code.contains('-')) {
        // Ticket ID
        await _processTicket(code);
      } else {
        // Game ID
        final exists = await FirestoreService().checkGameIdExists(code);
        if (exists) {
          // 1. Set Session & History
          await LocalDatabaseService().setCurrentGameId(code);
          await LocalDatabaseService().saveJoinedGame(code);
          
          // 2. Restore Tickets (if any)
          final tickets = await FirestoreService().getPlayerTickets(code, user.uid);
          if (tickets.isNotEmpty) {
             for (var t in tickets) {
               await LocalDatabaseService().saveTicket(code, t);
             }
             debugPrint('Restored ${tickets.length} tickets for game $code');
          }

          if (!mounted) return;
           // 3. Navigate
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PlayerTicketScreen(
                gameId: code,
              ),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Game Code $code not found')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isJoining
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'Enter Game Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask the host for the unique game code to get your tickets.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Game Code or Ticket ID',
                  hintText: 'e.g. ABCD or ABCD-1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.key),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _joinGame,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'JOIN / GET TICKET',
                  style: TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (scannerContext) {
                        bool isPopped = false;
                        return Scaffold(
                          appBar: AppBar(title: const Text('Scan Ticket QR')),
                          body: MobileScanner(
                            onDetect: (capture) {
                              if (isPopped) return;
                              final List<Barcode> barcodes = capture.barcodes;
                              for (final barcode in barcodes) {
                                if (barcode.rawValue != null) {
                                  String code = barcode.rawValue!;
                                  if (code.startsWith('tambola://ticket/')) {
                                    code = code.replaceAll('tambola://ticket/', '');
                                  }
                                  if (code.isNotEmpty) {
                                    isPopped = true;
                                    Navigator.of(scannerContext).pop(code);
                                    break;
                                  }
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  );
          
                  if (result != null && result is String) {
                    await _processTicket(result);
                  }
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('New: SCAN TICKET QR'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              if (_recentGames.isNotEmpty) ...[
                const SizedBox(height: 32),
                const Text(
                  'Recent Games',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  children: _recentGames.map((game) {
                    final gameId = game['gameId'] as String;
                    return ActionChip(
                      label: Text(gameId),
                      onPressed: () async {
                         _codeController.text = gameId; // Visual feedback
                         await LocalDatabaseService().setCurrentGameId(gameId);
                         if (!mounted) return;
                         Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerTicketScreen(gameId: gameId),
                            ),
                         );
                      },
                      avatar: const Icon(Icons.history, size: 16),
                    );
                  }).toList(),
                ),
              ],
            ],
                    ),
          ),
      ),
    );
  }
}
