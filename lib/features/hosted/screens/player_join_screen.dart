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

        // Save session immediately
        await LocalDatabaseService().setCurrentGameId(gameId);

        // 3. Pre-fetch and Save Ticket Locally
        try {
          final ticketData = await FirestoreService().getTicket(code);
          if (ticketData != null) {
            await LocalDatabaseService().saveTicket(gameId, ticketData);
            debugPrint('Pre-fetched and saved ticket $code locally.');
          }
        } catch (e) {
          debugPrint('Warning: Failed to pre-fetch ticket: $e');
          // Non-blocking: Proceed to navigation anyway, PlayerTicketScreen will retry.
        }

        if (!mounted) return;

        if (widget.isAddingMore) {
          // Just pop back to refresh the existing ticket screen
          Navigator.pop(context, code);
        } else {
          // 4. Navigate immediately (Let PlayerTicketScreen handle data fetching/caching)
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
          // 1. Set Session
          await LocalDatabaseService().setCurrentGameId(code);
          
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
          : Column(
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
          ],
        ),
      ),
    );
  }
}
