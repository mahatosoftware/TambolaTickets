import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';

class UnmoderatedDatabaseService {
  static final UnmoderatedDatabaseService _instance = UnmoderatedDatabaseService._internal();
  static Database? _database;

  factory UnmoderatedDatabaseService() => _instance;

  UnmoderatedDatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'unmoderated_tickets.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE unmoderated_tickets (
        id TEXT PRIMARY KEY,
        sessionId TEXT,
        createdAt TEXT,
        grid TEXT,
        markedNumbers TEXT
      )
    ''');
  }

  Future<void> createUnmoderatedTicket(Map<String, dynamic> ticketMap) async {
    final db = await database;
    await db.insert(
      'unmoderated_tickets',
      ticketMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllUnmoderatedTickets() async {
    final db = await database;
    // Order by createdAt descending
    return await db.query('unmoderated_tickets', orderBy: 'createdAt DESC');
  }
  
  Future<void> updateUnmoderatedTicketMarks(String id, List<int> marks) async {
    final db = await database;
    await db.update(
      'unmoderated_tickets',
      {'markedNumbers': jsonEncode(marks)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> deleteUnmoderatedTicket(String id) async {
    final db = await database;
    await db.delete(
      'unmoderated_tickets',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteUnmoderatedSession(String sessionId) async {
    final db = await database;
    await db.delete(
      'unmoderated_tickets',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteAllUnmoderatedTickets() async {
    final db = await database;
    await db.delete('unmoderated_tickets');
  }

  Future<bool> isUnmoderatedTicketIdTaken(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'unmoderated_tickets',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty;
  }
}
