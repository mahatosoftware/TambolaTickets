import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/widgets/tambola_ticket_card.dart';

class HostedTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  final String playerName;
  final bool initialActiveStatus;
  final List<List<int>> ticketData;

  const HostedTicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.playerName,
    required this.initialActiveStatus,
    required this.ticketData,
  });

  @override
  State<HostedTicketDetailScreen> createState() => _HostedTicketDetailScreenState();
}

class _HostedTicketDetailScreenState extends State<HostedTicketDetailScreen> {
  late bool _isActive;
  late List<List<int>> _ticketData;
  final Set<int> _markedNumbers = {};

  @override
  void initState() {
    super.initState();
    _isActive = widget.initialActiveStatus;
    _ticketData = widget.ticketData;
  }

  void _toggleActive() {
    setState(() {
      _isActive = !_isActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isActive ? 'Ticket Activated' : 'Ticket Deactivated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Extract GameID from TicketID (Format: GAMEID-SEQUENCE)
    final lastHyphen = widget.ticketId.lastIndexOf('-');
    final gameId = (lastHyphen != -1) ? widget.ticketId.substring(0, lastHyphen) : '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playerName),
        actions: [
          IconButton(
            icon: Icon(_isActive ? Icons.lock_open : Icons.lock),
            onPressed: _toggleActive,
            tooltip: _isActive ? 'Deactivate Ticket' : 'Activate Ticket',
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('games')
            .doc(gameId)
            .collection('tickets')
            .doc(widget.ticketId)
            .snapshots(includeMetadataChanges: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
             return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Use initial data if loading, or update from snapshot
          Set<int> currentMarks = _markedNumbers;
          
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final serverMarks = data['markedNumbers'];
            if (serverMarks is List) {
              currentMarks = Set<int>.from(serverMarks.map((e) => e as int));
            }
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Chip(
                        label: Text('Ticket #${widget.ticketId}'),
                        backgroundColor: Colors.blue[100],
                      ),
                      const SizedBox(width: 12),
                      Chip(
                        avatar: Icon(
                          _isActive ? Icons.check_circle : Icons.cancel,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          _isActive ? 'ACTIVE' : 'INACTIVE',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: _isActive ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_ticketData.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TambolaTicketCard(
                      ticketData: _ticketData,
                      markedNumbers: currentMarks,
                      onNumberTap: (number) {
                        // Host cannot mark numbers
                      },
                      isInteractive: false,
                      colorTheme: _isActive ? Colors.blue : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        const Text(
                          'Player Scan Code',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: QrImageView(
                            data: "tambola://ticket/${widget.ticketId}",
                            version: QrVersions.auto,
                            size: 150.0,
                            backgroundColor: Colors.white,
                            // style parameter removed as it is not supported in this version
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'Manual Paper Ticket\nNo digital view available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
