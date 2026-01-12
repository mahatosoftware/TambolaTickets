import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:math';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../../core/services/firestore_service.dart';
import 'host_dashboard_screen.dart';

class HostGameIdScreen extends StatefulWidget {
  const HostGameIdScreen({super.key});

  @override
  State<HostGameIdScreen> createState() => _HostGameIdScreenState();
}

class _HostGameIdScreenState extends State<HostGameIdScreen> {
  final TextEditingController _gameIdController = TextEditingController();
  bool _isGenerating = false;

  final FirestoreService _firestoreService = FirestoreService();
  
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
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

  void _scanQrCode() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (scannerContext) {
          bool isPopped = false;
          return Scaffold(
            appBar: AppBar(title: const Text('Scan Game ID')),
            body: MobileScanner(
              onDetect: (capture) {
                if (isPopped) return;
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  if (barcode.rawValue != null) {
                     String code = barcode.rawValue!;
                     // If it's a ticket URL (tambola://ticket/GAMEID-TicketID), extract GameID
                     if (code.startsWith('tambola://ticket/')) {
                        code = code.replaceAll('tambola://ticket/', '');
                        if (code.contains('-')) {
                           code = code.split('-')[0];
                        }
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
      setState(() {
        _gameIdController.text = result;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scanned Game ID: $result')),
        );
      }
    }
  }

  void _proceedToSetup() {
    if (_gameIdController.text.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => HostDashboardScreen(
            bulkCount: 5,
            gameId: _gameIdController.text,
          ),
        ),
      );
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
                    'Scan a QR code from a previous session, generate a unique ID, or enter one manually.',
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
                    // readOnly: false, // Default is false, allowing manual typing
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _scanQrCode,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('SCAN QR'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.blueGrey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _generateGameId,
                          icon: _isGenerating 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                            : const Icon(Icons.auto_awesome),
                          label: const Text('GENERATE'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
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
                  const SizedBox(height: 24),
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
