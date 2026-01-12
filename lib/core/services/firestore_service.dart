import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> saveGameSession({
    required String gameId,
    required int digitalCount,
    required int manualCount,
  }) async {
    await _firestore.collection('games').doc(gameId).set({
      'gameId': gameId,
      'createdAt': FieldValue.serverTimestamp(),
      'digitalCount': digitalCount,
      'manualCount': manualCount,
    }, SetOptions(merge: true));
  }

  Future<void> saveTicket(String gameId, Map<String, dynamic> ticketData) async {
    final ticketId = ticketData['id'];
    
    // Convert nested List<List<int>> to a Map for Firestore (it doesn't support nested arrays)
    final rawData = ticketData['ticketData'];
    Map<String, dynamic> firestoreData = {};
    
    if (rawData is List && rawData.isNotEmpty && rawData.first is List) {
      // It's a generated 3x9 grid
      firestoreData = {
        'row0': rawData[0],
        'row1': rawData[1],
        'row2': rawData[2],
      };
    } 
    
    await _firestore
        .collection('games')
        .doc(gameId)
        .collection('tickets')
        .doc(ticketId)
        .set({
      'id': ticketId,
      'name': ticketData['name'],
      'type': ticketData['type'],
      'isActive': ticketData['isActive'],
      'createdAt': FieldValue.serverTimestamp(),
      'grid': firestoreData, // identifiable and reconstructible
      'isManual': (ticketData['type'] as String).toLowerCase().contains('paper'),
    });
    debugPrint('Saved ticket $ticketId to Firestore');
  }

  Future<Map<String, dynamic>?> getTicket(String ticketId) async {
    try {
      final lastHyphenIndex = ticketId.lastIndexOf('-');
      if (lastHyphenIndex == -1) return null;
      
      final gameId = ticketId.substring(0, lastHyphenIndex);
      final doc = await _firestore
          .collection('games')
          .doc(gameId)
          .collection('tickets')
          .doc(ticketId)
          .get();
          
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      debugPrint('Error getting ticket: $e');
      return null;
    }
  }

  Stream<List<Map<String, dynamic>>> getGameTicketsStream(String gameId) {
    return _firestore
        .collection('games')
        .doc(gameId)
        .collection('tickets')
        .orderBy('createdAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<List<Map<String, dynamic>>> getPlayerTickets(String gameId, String uid) async {
    try {
      final snapshot = await _firestore
          .collection('games')
          .doc(gameId)
          .collection('tickets')
          .where('playerUid', isEqualTo: uid)
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint('Error getting player tickets: $e');
      return [];
    }
  }

  Future<bool> checkGameIdExists(String gameId) async {
    try {
      final doc = await _firestore.collection('games').doc(gameId).get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking game ID: $e');
      return false; 
    }
  }

  Future<void> saveUser(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final counterRef = _firestore.collection('config').doc('counters');

    try {
      await _firestore.runTransaction((transaction) async {
        final userSnapshot = await transaction.get(userRef);

        if (userSnapshot.exists &&
            userSnapshot.data() != null &&
            (userSnapshot.data() as Map<String, dynamic>).containsKey('playerId')) {
          // User already has ID, just update metadata
          transaction.set(
            userRef,
            {
              'displayName': user.displayName ?? 'No Name',
              'email': user.email ?? '',
              'photoURL': user.photoURL ?? '',
              'lastLogin': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          return;
        }

        // User needs a new ID
        final counterSnapshot = await transaction.get(counterRef);
        int currentId = 1000; // Default start

        if (counterSnapshot.exists && counterSnapshot.data() != null) {
          final data = counterSnapshot.data() as Map<String, dynamic>;
          if (data.containsKey('lastPlayerId')) {
            currentId = data['lastPlayerId'] as int;
          }
        }

        final nextId = currentId + 1;
        final nextIdString = nextId.toString();

        // Update counter
        transaction.set(
          counterRef,
          {'lastPlayerId': nextId},
          SetOptions(merge: true),
        );

        // Create/Update user with new ID
        transaction.set(
          userRef,
          {
            'uid': user.uid,
            'displayName': user.displayName ?? 'No Name',
            'email': user.email ?? '',
            'photoURL': user.photoURL ?? '',
            'playerId': nextIdString,
            'lastLogin': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
      debugPrint('User data saved/updated for ${user.uid}');
    } catch (e) {
      debugPrint('Error saving user data (transaction): $e');
    }
  }

  Future<DocumentSnapshot> getUser(String uid) {
    return _firestore.collection('users').doc(uid).get();
  }

  Future<void> updateUserName(String uid, String name) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'displayName': name,
      });
    } catch (e) {
      debugPrint('Error updating user name: $e');
      rethrow;
    }
  }

  Future<void> claimTicket(String ticketId, String uid) async {
    try {
      // 1. Get User Info
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) throw Exception('User not found');

      final userData = userDoc.data()!;
      final playerId = userData['playerId'] as String?;
      final playerName = userData['displayName'] as String? ?? 'Unknown';

      if (playerId == null) throw Exception('Player ID not found for user');

      // 2. Parse gameId from ticketId (Assuming format: GAMEID-SEQUENCE)
      // We look for the last hyphen to handle cases where Game ID itself has hyphens
      final lastHyphenIndex = ticketId.lastIndexOf('-');
      if (lastHyphenIndex == -1) throw Exception('Invalid Ticket ID format');

      final gameId = ticketId.substring(0, lastHyphenIndex);

      // 3. Update Ticket
      await _firestore
          .collection('games')
          .doc(gameId)
          .collection('tickets')
          .doc(ticketId)
          .update({
        'playerId': playerId,
        'playerUid': uid,
        'name': playerName,
        'claimedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint('Ticket $ticketId claimed by $playerName ($playerId)');
    } catch (e) {
      debugPrint('Error claiming ticket: $e');
      rethrow;
    }
  }

  Future<void> updateTicketStatus(String gameId, String ticketId, bool isActive) async {
    await _firestore
        .collection('games')
        .doc(gameId)
        .collection('tickets')
        .doc(ticketId)
        .update({'isActive': isActive});
  }

  Future<void> submitWinClaim({
    required String gameId,
    required String playerUid,
    required String playerName,
    required Map<String, List<int>> markedData,
  }) async {
    try {
      final batch = _firestore.batch();
      
      // 1. Create Claim Document
      final claimRef = _firestore.collection('games').doc(gameId).collection('claims').doc();
      batch.set(claimRef, {
        'playerUid': playerUid,
        'playerName': playerName,
        'markedData': markedData,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      // 2. Update each ticket with marked numbers
      for (final entry in markedData.entries) {
        final ticketId = entry.key;
        final marks = entry.value;
        
        final ticketRef = _firestore
            .collection('games')
            .doc(gameId)
            .collection('tickets')
            .doc(ticketId);
            
        batch.update(ticketRef, {'markedNumbers': marks});
      }

      await batch.commit();
      debugPrint('Win claim submitted for $playerName with persistence');
    } catch (e) {
      debugPrint('Error submitting win claim: $e');
      rethrow;
    }
  }
}
