import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'features/home/screens/home_screen.dart';
import 'features/auth/screens/login_screen.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Ensure portrait mode for a better ticket experience on phones
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  MobileAds.instance.initialize();

  try {
    await Firebase.initializeApp();
    // Enable Firestore persistence and set cache size to unlimited
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  runApp(const TambolaApp());
}

class TambolaApp extends StatelessWidget {
  const TambolaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return MultiProvider(
      providers: [
        // TODO: Add providers here later
        Provider<AuthService>(create: (_) => authService),
      ],
      child: MaterialApp(
        title: 'Tambola Tickets',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: StreamBuilder<User?>(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active) {
              if (snapshot.hasData) {
                if (snapshot.data!.emailVerified) {
                  return const HomeScreen();
                } else {
                  // User is signed in but not verified. 
                  // We show LoginScreen to force them to verify or login again after verification.
                  // Ideally, we might want to sign them out here to clean up state, 
                  // but build methods shouldn't trigger side effects directly.
                  // The LoginScreen allows them to re-initiate login which checks verification.
                  return const LoginScreen();
                }
              } else {
                return const LoginScreen();
              }
            }
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
        ),
      ),
    );
  }
}
