import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirestoreService _firestoreService = FirestoreService();

  // Stream to listen to auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled the sign-in

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Once signed in, return the UserCredential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Save user data to Firestore
      if (userCredential.user != null) {
        await _firestoreService.saveUser(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      debugPrint("Error signing in with Google: $e");
      return null;
    }
  }

  // Sign in with Email and Password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email address to log in.',
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-not-verified') rethrow;
      debugPrint("Error signing in with Email: $e");
      return null;
    } catch (e) {
      debugPrint("Error signing in with Email: $e");
      return null;
    }
  }

  // Sign up with Email and Password
  Future<UserCredential?> signUpWithEmailAndPassword(String email, String password, String name) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      if (userCredential.user != null) {
        await userCredential.user!.updateDisplayName(name);
        await userCredential.user!.reload();
        
        // Send verification email
        await userCredential.user!.sendEmailVerification();
        
        // Save user to Firestore
        await _firestoreService.saveUser(userCredential.user!); 
        await _firestoreService.updateUserName(userCredential.user!.uid, name);
      }

      return userCredential;
    } catch (e) {
      debugPrint("Error signing up with Email: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Error signing out: $e");
    }
  }

  // Verify if user still exists
  Future<void> verifyUser() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'user-not-found' || e.code == 'user-disabled') {
          await signOut();
        }
      } catch (e) {
        debugPrint("Error verifying user: $e");
      }
    }
  }
}
