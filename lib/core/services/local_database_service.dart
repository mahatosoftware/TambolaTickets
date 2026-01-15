import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalDatabaseService {
  static final LocalDatabaseService _instance = LocalDatabaseService._internal();
  static Database? _database;

  factory LocalDatabaseService() => _instance;

  LocalDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tambola_tickets.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Stores the current active game session
    await db.execute('''
      CREATE TABLE game_session (
        gameId TEXT PRIMARY KEY,
        joinedAt TEXT
      )
    ''');

    // Stores tickets for the ACTIVE game session
    await db.execute('''
      CREATE TABLE tickets (
        ticketId TEXT PRIMARY KEY,
        ticketData TEXT
      )
    ''');
    
    // Stores history of generated IDs
    await db.execute('''
      CREATE TABLE generated_game_ids (
        gameId TEXT PRIMARY KEY,
        createdAt TEXT
      )
    ''');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
     if (oldVersion < 4) {
       await db.execute('''
        CREATE TABLE generated_game_ids (
          gameId TEXT PRIMARY KEY,
          createdAt TEXT
        )
      ''');
     }
  }

  // Ensures only one game session exists. Wipes old data if gameId changes.
  Future<void> _ensureGameSession(String gameId) async {
    final db = await database;
    
    // Check current session
    final List<Map<String, dynamic>> sessions = await db.query('game_session');
    
    if (sessions.isNotEmpty) {
      final currentSession = sessions.first;
      if (currentSession['gameId'] != gameId) {
        debugPrint('New game detected: $gameId. Wiping old data from ${currentSession['gameId']}');
        // New game! Wipe everything
        await db.delete('tickets');
        await db.delete('game_session');
        await db.insert('game_session', {
          'gameId': gameId,
          'joinedAt': DateTime.now().toIso8601String(),
        });
      }
      // Else: Same game, do nothing
    } else {
       // No session exists, create one
       await db.insert('game_session', {
        'gameId': gameId,
        'joinedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> saveTicket(String gameId, Map<String, dynamic> ticketData) async {
    final db = await database;
    
    // 1. Ensure correct game session (handles wiping)
    await _ensureGameSession(gameId);

    // 2. Save/Update ticket
    String ticketId;
    if (ticketData.containsKey('id')) {
      ticketId = ticketData['id'];
    } else {
       ticketId = ticketData['id'] ?? 'unknown'; 
    }

    await db.insert(
      'tickets',
      {
        'ticketId': ticketId,
        'ticketData': jsonEncode(ticketData, toEncodable: (nonEncodable) {
          if (nonEncodable is Timestamp) {
            return nonEncodable.toDate().toIso8601String();
          }
          return nonEncodable;
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTickets() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('tickets');

    return List.generate(maps.length, (i) {
      return jsonDecode(maps[i]['ticketData']);
    });
  }

  Future<String?> getCurrentGameId() async {
    final db = await database;
    final List<Map<String, dynamic>> sessions = await db.query('game_session');
    if (sessions.isNotEmpty) {
      return sessions.first['gameId'] as String;
    }
    return null;
  }

  Future<void> setCurrentGameId(String gameId) async {
    await _ensureGameSession(gameId);
  }
  
  Future<void> saveGeneratedGameId(String gameId) async {
    final db = await database;
    await db.insert(
      'generated_game_ids',
      {
        'gameId': gameId,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<List<Map<String, dynamic>>> getRecentGeneratedGameIds() async {
    final db = await database;
    // Get time 48 hours ago
    final twoDaysAgo = DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();
    
    return await db.query(
      'generated_game_ids',
      where: 'createdAt > ?',
      whereArgs: [twoDaysAgo],
      orderBy: 'createdAt DESC',
    );
  }
}
