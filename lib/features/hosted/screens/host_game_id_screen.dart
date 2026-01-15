import 'package:flutter/material.dart';

import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/services/firestore_service.dart';
import 'host_dashboard_screen.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/local_database_service.dart';

class HostGameIdScreen extends StatefulWidget {
  const HostGameIdScreen({super.key});

  @override
  State<HostGameIdScreen> createState() => _HostGameIdScreenState();
}

class _HostGameIdScreenState extends State<HostGameIdScreen> {
  final TextEditingController _gameIdController = TextEditingController();
  bool _isGenerating = false;
  List<Map<String, dynamic>> _recentGameIds = [];

  final FirestoreService _firestoreService = FirestoreService();
  final LocalDatabaseService _localDatabaseService = LocalDatabaseService();
  
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadRecentGameIds();
  }
  
  void _loadRecentGameIds() async {
    final ids = await _localDatabaseService.getRecentGeneratedGameIds();
    if (mounted) {
      setState(() {
        _recentGameIds = ids;
      });
    }
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // Test Banner ID
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('BannerAd failed to load: $error');
          ad.dispose();
        },
      ),
    );
    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    _gameIdController.dispose();
    super.dispose();
  }

  void _generateGameId() async {
    setState(() {
      _isGenerating = true;
    });

    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    String newId = '';
    bool exists = true;

    // Loop until we find a unique ID
    while (exists) {
      newId = String.fromCharCodes(Iterable.generate(
        6,
        (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
      ));

      // Check if it already exists in DB
      exists = await _firestoreService.checkGameIdExists(newId);
      if (exists) {
        debugPrint('Generated ID $newId already exists, retrying...');
      }
    }

    if (mounted) {
      setState(() {
        _gameIdController.text = newId;
        _isGenerating = false;
      });
    }
  }



  void _proceedToSetup() async {
    if (_gameIdController.text.isNotEmpty) {
      // Save ID to local history
      await _localDatabaseService.saveGeneratedGameId(_gameIdController.text);
      
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HostDashboardScreen(
            bulkCount: 5,
            gameId: _gameIdController.text,
          ),
        ),
      ).then((_) {
         // Refresh list when returning (in case user started a new game and came back)
         _loadRecentGameIds();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please generate or scan a Game ID first.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Game Setup'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Set Game ID',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generate a unique ID or pick from recent history.',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _gameIdController,
                    decoration: const InputDecoration(
                      labelText: 'Game ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.tag),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    readOnly: true,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _generateGameId,
                    icon: _isGenerating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                      : const Icon(Icons.auto_awesome),
                    label: const Text('GENERATE'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _proceedToSetup,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                   if (_recentGameIds.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Recent Game IDs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _recentGameIds.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = _recentGameIds[index];
                            final date = DateTime.parse(item['createdAt']);
                            final formattedDate = DateFormat('MMM d, h:mm a').format(date);
                            
                            return ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(
                                item['gameId'],
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(formattedDate),
                              onTap: () {
                                setState(() {
                                  _gameIdController.text = item['gameId'];
                                });
                              },
                              contentPadding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            );
                          },
                        ),
                      ),
                   ],
                ],
              ),
            ),
          ),
          if (_isAdLoaded && _bannerAd != null)
            SizedBox(
              width: _bannerAd!.size.width.toDouble(),
              height: _bannerAd!.size.height.toDouble(),
              child: AdWidget(ad: _bannerAd!),
            ),
        ],
      ),
    );
  }
}
