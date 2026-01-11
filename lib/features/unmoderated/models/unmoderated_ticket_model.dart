import 'dart:convert';

class UnmoderatedTicket {
  final String id;
  final String? sessionId;
  final DateTime createdAt;
  final List<List<int>> grid; // 3x9 grid
  final List<int> markedNumbers; // List of flattened numbers or just the numbers themselves?
  // Let's store the actual numbers that are marked.

  UnmoderatedTicket({
    required this.id,
    this.sessionId,
    required this.createdAt,
    required this.grid,
    this.markedNumbers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'createdAt': createdAt.toIso8601String(),
      'grid': jsonEncode(grid),
      'markedNumbers': jsonEncode(markedNumbers),
    };
  }

  factory UnmoderatedTicket.fromMap(Map<String, dynamic> map) {
    // Decode grid: List<dynamic> (outer) -> List<dynamic> (rows) -> int
    final rawGrid = jsonDecode(map['grid'] as String) as List;
    final List<List<int>> grid = rawGrid.map((row) {
      return (row as List).map((e) => e as int).toList();
    }).toList();

    // Decode markedNumbers
    final rawMarks = jsonDecode(map['markedNumbers'] as String) as List;
    final List<int> markedNumbers = rawMarks.map((e) => e as int).toList();

    return UnmoderatedTicket(
      id: map['id'] as String,
      sessionId: map['sessionId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      grid: grid,
      markedNumbers: markedNumbers,
    );
  }

  UnmoderatedTicket copyWith({
    String? id,
    String? sessionId,
    DateTime? createdAt,
    List<List<int>>? grid,
    List<int>? markedNumbers,
  }) {
    return UnmoderatedTicket(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      createdAt: createdAt ?? this.createdAt,
      grid: grid ?? this.grid,
      markedNumbers: markedNumbers ?? this.markedNumbers,
    );
  }
}
