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
      version: 6,
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

    // Stores tickets for ALL games
    await db.execute('''
      CREATE TABLE tickets (
        ticketId TEXT PRIMARY KEY,
        gameId TEXT,
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

     // Stores history of joined IDs
    await db.execute('''
      CREATE TABLE joined_game_history (
        gameId TEXT PRIMARY KEY,
        joinedAt TEXT
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

     if (oldVersion < 5) {
       await db.execute('''
        CREATE TABLE joined_game_history (
          gameId TEXT PRIMARY KEY,
          joinedAt TEXT
        )
      ''');
     }

     if (oldVersion < 6) {
       // Add gameId column to tickets table
       // SQLite doesn't support adding column with constraints easily if table exists, 
       // but for simplicity we just ADD COLUMN.
       try {
         await db.execute('ALTER TABLE tickets ADD COLUMN gameId TEXT');
       } catch (e) {
         // Column might already exist if re-running
         debugPrint('Migration error (tickets gameId): $e');
       }
     }
  }

  // Ensures only one game session exists. 
  Future<void> _ensureGameSession(String gameId) async {
    final db = await database;
    
    // Check current session
    final List<Map<String, dynamic>> sessions = await db.query('game_session');
    
    if (sessions.isNotEmpty) {
      final currentSession = sessions.first;
      if (currentSession['gameId'] != gameId) {
        debugPrint('New game detected: $gameId. Updating session.');
        await db.delete('game_session');
        await db.insert('game_session', {
          'gameId': gameId,
          'joinedAt': DateTime.now().toIso8601String(),
        });
      }
    } else {
       await db.insert('game_session', {
        'gameId': gameId,
        'joinedAt': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> saveTicket(String gameId, Map<String, dynamic> ticketData) async {
    final db = await database;
    
    await _ensureGameSession(gameId);

    // 2. Save/Update ticket
    String ticketId;
    if (ticketData.containsKey('id')) {
      ticketId = ticketData['id'];
    } else {
       ticketId = ticketData['id'] ?? 'unknown'; 
    }
    
    // Ensure we don't overwrite markedNumbers if we are just resaving structure
    // Fetch existing
    List<dynamic>? existingMarks;
    final List<Map<String, dynamic>> existing = await db.query(
      'tickets', 
      where: 'ticketId = ?', 
      whereArgs: [ticketId]
    );
    
    if (existing.isNotEmpty) {
      final existingData = jsonDecode(existing.first['ticketData'] as String);
      if (existingData['markedNumbers'] != null) {
        existingMarks = existingData['markedNumbers'];
      }
    }
    
    if (existingMarks != null) {
      ticketData['markedNumbers'] = existingMarks;
    }

    await db.insert(
      'tickets',
      {
        'ticketId': ticketId,
        'gameId': gameId,
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

  Future<List<Map<String, dynamic>>> getTickets(String? gameId) async {
    final db = await database;
    
    List<Map<String, dynamic>> maps;
    if (gameId != null) {
       maps = await db.query('tickets', where: 'gameId = ?', whereArgs: [gameId]);
    } else {
       maps = await db.query('tickets');
    }

    return List.generate(maps.length, (i) {
      return jsonDecode(maps[i]['ticketData']);
    });
  }
  
  Future<void> updateTicketMarkedNumbers(String ticketId, List<int> markedNumbers) async {
    final db = await database;
    
    // 1. Get current ticket data
    final List<Map<String, dynamic>> maps = await db.query(
      'tickets', 
      where: 'ticketId = ?', 
      whereArgs: [ticketId]
    );
    
    if (maps.isEmpty) return;
    
    final row = maps.first;
    final Map<String, dynamic> ticketData = jsonDecode(row['ticketData'] as String);
    
    // 2. Update marked numbers
    ticketData['markedNumbers'] = markedNumbers;
    
    // 3. Save back
    await db.update(
      'tickets',
      {
        'ticketData': jsonEncode(ticketData),
      },
      where: 'ticketId = ?',
      whereArgs: [ticketId],
    );
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
    
    // DELETE games older than 48 hours
    await db.delete(
      'generated_game_ids',
      where: 'createdAt <= ?',
      whereArgs: [twoDaysAgo],
    );
    debugPrint('Deleted local games older than $twoDaysAgo');
    
    return await db.query(
      'generated_game_ids',
      orderBy: 'createdAt DESC',
    );
  }

  // --- Joined Game History ---

  Future<void> saveJoinedGame(String gameId) async {
    final db = await database;
    await db.insert(
      'joined_game_history',
      {
        'gameId': gameId,
        'joinedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getRecentJoinedGames() async {
    final db = await database;
    final twoDaysAgo = DateTime.now().subtract(const Duration(hours: 48)).toIso8601String();

    // Clean up old history
    await db.delete(
      'joined_game_history',
      where: 'joinedAt <= ?',
      whereArgs: [twoDaysAgo],
    );

    return await db.query(
      'joined_game_history',
      orderBy: 'joinedAt DESC',
    );
  }
}
