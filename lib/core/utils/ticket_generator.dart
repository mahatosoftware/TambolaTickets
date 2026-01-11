import 'dart:math';

class TambolaTicketGenerator {
  static List<List<int>> generateTicket() {
    final Random random = Random();
    final List<List<int>> ticket = List.generate(3, (_) => List.filled(9, 0));

    // Ranges for each column
    // Col 0: 1-9 (9 nums)
    // Col 1: 10-19 (10 nums)
    // ...
    // Col 8: 80-90 (11 nums)
    final List<List<int>> columnRanges = [
      List.generate(9, (i) => i + 1), // 1-9
      List.generate(10, (i) => 10 + i), // 10-19
      List.generate(10, (i) => 20 + i), // 20-29
      List.generate(10, (i) => 30 + i), // 30-39
      List.generate(10, (i) => 40 + i), // 40-49
      List.generate(10, (i) => 50 + i), // 50-59
      List.generate(10, (i) => 60 + i), // 60-69
      List.generate(10, (i) => 70 + i), // 70-79
      List.generate(11, (i) => 80 + i), // 80-90
    ];

    // Ensure each column has at least 1 number.
    // We need 15 numbers total.
    // 9 columns get 1 number each, leaving 6 numbers to distribute.
    List<int> numbersPerColumn = List.filled(9, 1);
    int remainingNumbers = 15 - 9;

    while (remainingNumbers > 0) {
      int colIndex = random.nextInt(9);
      // A column can have at most 3 numbers (since there are 3 rows)
      if (numbersPerColumn[colIndex] < 3) {
        numbersPerColumn[colIndex]++;
        remainingNumbers--;
      }
    }

    // Now populate numbers for each column based on count
    // columnNumbers will store the sorted numbers for each column
    List<List<int>> columnNumbers = [];
    for (int i = 0; i < 9; i++) {
      List<int> range = List.from(columnRanges[i]);
      range.shuffle(random);
      List<int> selected = range.take(numbersPerColumn[i]).toList();
      selected.sort();
      columnNumbers.add(selected);
    }

    // Assign numbers to rows
    // This part is tricky: we need to place numbers in the 3x9 grid
    // satisfying: 5 numbers per row, correct columns, sorted in columns.
    
    // We will use a randomized backtracking or greedy approach with checks.
    // Since we simplified, let's try a direct placement logic.
    // We know how many items are in each column.
    // We need to decide for each number in a column, which row it goes to.
    
    // Structure to hold which rows in a column are occupied.
    // 0 = empty, 1 = occupied.
    List<List<int>> gridStructure = List.generate(3, (_) => List.filled(9, 0));
    
    // Counters for numbers per row
    List<int> rowCounts = [0, 0, 0];

    // Strategy:
    // 1. Columns with 3 numbers MUST occupy all 3 rows.
    // 2. Columns with 2 numbers MUST occupy 2 rows.
    // 3. Columns with 1 number MUST occupy 1 row.
    // We need to balance rowCounts to be exactly 5.

    // Using a refined approach to ensure valid distribution:
    // First, Fill columns with 3 items.
    for (int c = 0; c < 9; c++) {
      if (numbersPerColumn[c] == 3) {
        gridStructure[0][c] = 1;
        gridStructure[1][c] = 1;
        gridStructure[2][c] = 1;
        rowCounts[0]++;
        rowCounts[1]++;
        rowCounts[2]++;
      }
    }

    // Then handle remaining columns. We need to assign them to rows ensuring no row exceeds 5.
    // This is a constraint satisfaction problem. 
    // Simplified generator:
    // Iterate remaining columns, try to place in rows with least counts, while valid.
    
    // Let's restart the distribution loop specifically for the placement part if it fails.
    // Or use a known valid pattern generator.
    
    // Retrying approach is safer for simplicity here.
    bool success = false;
    while (!success) {
      // Reset
      gridStructure = List.generate(3, (_) => List.filled(9, 0));
      rowCounts = [0, 0, 0];
      success = true;

      // 1. Fill 3-item columns
      for (int c = 0; c < 9; c++) {
        if (numbersPerColumn[c] == 3) {
          gridStructure[0][c] = 1;
          gridStructure[1][c] = 1;
          gridStructure[2][c] = 1;
          rowCounts[0]++;
          rowCounts[1]++;
          rowCounts[2]++;
        }
      }

      // 2. Fill 2-item columns
      for (int c = 0; c < 9; c++) {
        if (numbersPerColumn[c] == 2) {
           // We need to pick 2 rows out of 3.
           // Prefer rows with lower counts if possible, but randomness is good.
           List<int> rows = [0, 1, 2]..shuffle(random);
           
           // Heuristic: check if adding to these rows exceeds 5 (if we can avoid it).
           // But since we have tight constraints, let's just pick and check at the end.
           // Actually, we must ensure we don't blockade 1-item columns.
           // Let's try to balance immediately.
           
           // Find row with MAX count to avoid.
           int maxRow = -1;
           int maxVal = -1;
           for(int r=0; r<3; r++) {
             if (rowCounts[r] > maxVal) {
               maxVal = rowCounts[r];
               maxRow = r;
             }
           }
           
           // If we have a clear max, avoid it. Else random.
           // If all equal, random.
           List<int> chosenRows = [];
           if (maxVal > rowCounts[(maxRow + 1) % 3] && maxVal > rowCounts[(maxRow + 2) % 3]) {
              // One row is strictly larger, avoid it.
              for(int r=0; r<3; r++) {
                if (r != maxRow) chosenRows.add(r);
              }
           } else {
             // Random 2
              chosenRows = rows.sublist(0, 2);
           }
           
           for (int r in chosenRows) {
             gridStructure[r][c] = 1;
             rowCounts[r]++;
           }
        }
      }

      // 3. Fill 1-item columns
      for (int c = 0; c < 9; c++) {
        if (numbersPerColumn[c] == 1) {
          // Pick 1 row. Prefer row with MIN count.
          List<int> rows = [0, 1, 2];
           int minRow = 0;
           int minVal = 10;
           List<int> candidates = [];
           
           for(int r=0; r<3; r++) {
             if (rowCounts[r] < minVal) {
               minVal = rowCounts[r];
             }
           }
           for(int r=0; r<3; r++) {
             if (rowCounts[r] == minVal) candidates.add(r);
           }
           
           int chosenRow = candidates[random.nextInt(candidates.length)];
           gridStructure[chosenRow][c] = 1;
           rowCounts[chosenRow]++;
        }
      }
      
      // Check constraints
      if (rowCounts[0] != 5 || rowCounts[1] != 5 || rowCounts[2] != 5) {
        success = false;
        // The distribution of numbers per column might be awkward, 
        // OR the row assignment failed.
        // We can just retry the row assignment for the SAME column counts? 
        // Or simpler: just continue the outer loop and re-roll column counts too (by implicit recursion or just failing this function call - but unsafe).
        // Let's simple re-roll the loop.
        // To prevent infinite loop, we could create a better heuristic, but random retry works fast for 3x9.
      } else {
        // Additional check: Ensure column ordering is respected?
        // Logic: if a column has numbers in row 0, 1, 2 -> they take indices 0, 1, 2 of sorted list.
        // If row 0, 2 -> index 0 goes to row 0, index 1 goes to row 2.
        // This is always possible.
      }
    }

    // Populate the ticket with actual numbers
    for (int c = 0; c < 9; c++) {
      List<int> nums = columnNumbers[c];
      int currentNumIndex = 0;
      for (int r = 0; r < 3; r++) {
        if (gridStructure[r][c] == 1) {
          ticket[r][c] = nums[currentNumIndex];
          currentNumIndex++;
        } else {
          ticket[r][c] = 0; // Empty
        }
      }
    }

    return ticket;
  }
}
