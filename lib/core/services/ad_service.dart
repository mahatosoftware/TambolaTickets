import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoading = false;

  // Test Interstitial Ad ID (Android). ca-app-pub-3940256099942544/4411468910
  static const String _androidInterstitialAdUnitId = 'ca-app-pub-8382655413286804/5750068708';
  // Test Interstitial Ad ID (iOS)
  static const String _iosInterstitialAdUnitId = 'ca-app-pub-3940256099942544/4411468910';

  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return _androidInterstitialAdUnitId;
    } else if (Platform.isIOS) {
      return _iosInterstitialAdUnitId;
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  // Banner Ad IDs Test ca-app-pub-3940256099942544/6300978111
  static const String _androidBannerAdUnitId = 'ca-app-pub-8382655413286804/2438743187'; // Actual
  static const String _iosBannerAdUnitId = 'ca-app-pub-3940256099942544/2934735716'; // Test

  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _androidBannerAdUnitId;
    } else if (Platform.isIOS) {
      return _iosBannerAdUnitId;
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  void loadInterstitialAd() {
    if (_isAdLoading || _interstitialAd != null) return;

    _isAdLoading = true;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoading = false;
          debugPrint('InterstitialAd loaded');
          _setAdListeners(ad);
        },
        onAdFailedToLoad: (error) {
          _isAdLoading = false;
          _interstitialAd = null;
          debugPrint('InterstitialAd failed to load: $error');
        },
      ),
    );
  }

  void _setAdListeners(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('InterstitialAd dismissed');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next ad
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('InterstitialAd failed to show: $error');
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Retry preloading
      },
    );
  }

  void showInterstitialAd({required VoidCallback onAdDismissed}) {
    if (_interstitialAd != null) {
      // Save original dismiss callback to execute it
      final originalCallback = _interstitialAd!.fullScreenContentCallback;
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          originalCallback?.onAdDismissedFullScreenContent?.call(ad);
          onAdDismissed();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          originalCallback?.onAdFailedToShowFullScreenContent?.call(ad, error);
          onAdDismissed(); // Still proceed if ad failed to show
        },
        onAdShowedFullScreenContent: originalCallback?.onAdShowedFullScreenContent,
        onAdImpression: originalCallback?.onAdImpression,
        onAdClicked: originalCallback?.onAdClicked,
        onAdWillDismissFullScreenContent: originalCallback?.onAdWillDismissFullScreenContent,
      );
      _interstitialAd!.show();
    } else {
      debugPrint('InterstitialAd not ready yet');
      onAdDismissed();
      loadInterstitialAd(); // Try loading for next time
    }
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
