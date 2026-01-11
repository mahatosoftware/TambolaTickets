import 'package:flutter_test/flutter_test.dart';
import 'package:tambola_tickets/core/utils/ticket_generator.dart';

void main() {
  group('TambolaTicketGenerator Tests', () {
    test('Generate Ticket has correct structure (3x9)', () {
      final ticket = TambolaTicketGenerator.generateTicket();
      expect(ticket.length, 3);
      for (var row in ticket) {
        expect(row.length, 9);
      }
    });

    test('Ticket has exactly 15 numbers', () {
      final ticket = TambolaTicketGenerator.generateTicket();
      int count = 0;
      for (var row in ticket) {
        for (var num in row) {
          if (num != 0) count++;
        }
      }
      expect(count, 15);
    });

    test('Columns have correct number ranges', () {
      final ticket = TambolaTicketGenerator.generateTicket();
      
      // Transpose to check columns easily
      for (int c = 0; c < 9; c++) {
        List<int> colNums = [];
        for (int r = 0; r < 3; r++) {
          if (ticket[r][c] != 0) {
            colNums.add(ticket[r][c]);
            
            // Range checks
            if (c == 0) expect(ticket[r][c] >= 1 && ticket[r][c] <= 9, true);
            else if (c == 8) expect(ticket[r][c] >= 80 && ticket[r][c] <= 90, true);
            else {
              int start = c * 10;
              int end = start + 9;
              expect(ticket[r][c] >= start && ticket[r][c] <= end, true);
            }
          }
        }
        
        // Ensure column is sorted
        List<int> sorted = List.from(colNums)..sort();
        expect(colNums, sorted);
        
        // Ensure at least 1 number per column
        expect(colNums.isNotEmpty, true);
      }
    });

    test('Rows have exactly 5 numbers', () {
      final ticket = TambolaTicketGenerator.generateTicket();
      for (var row in ticket) {
        int count = row.where((n) => n != 0).length;
        expect(count, 5);
      }
    });
  });
}
