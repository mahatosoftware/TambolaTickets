import 'package:flutter/material.dart';

class TambolaTicketCard extends StatelessWidget {
  final List<List<int>> ticketData; // 3 rows x 9 cols. 0 means empty.
  final Set<int> markedNumbers;
  final Function(int) onNumberTap;
  final bool isInteractive;
  final String? ticketLabel;
  final Color? colorTheme;

  const TambolaTicketCard({
    super.key,
    required this.ticketData,
    required this.markedNumbers,
    required this.onNumberTap,
    this.isInteractive = true,
    this.ticketLabel,
    this.colorTheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = colorTheme ?? theme.colorScheme.primary;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ticketLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Text(
                ticketLabel!,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Table(
              border: TableBorder.all(
                color: theme.dividerColor,
                width: 1,
                borderRadius: BorderRadius.circular(4),
                style: BorderStyle.solid,
              ),
              children: List.generate(3, (rowIndex) {
                return TableRow(
                  children: List.generate(9, (colIndex) {
                    final number = ticketData[rowIndex][colIndex];
                    final isMarked = markedNumbers.contains(number);
                    final isEmpty = number == 0;

                    return GestureDetector(
                      onTap: (isEmpty || !isInteractive)
                          ? null
                          : () => onNumberTap(number),
                      child: Container(
                        height: 40, // Fixed height for consistency
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isEmpty
                              ? Colors.grey[100]
                              : (isMarked
                                  ? primaryColor.withOpacity(0.2)
                                  : Colors.white),
                        ),
                        child: isEmpty
                            ? null
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Text(
                                    number.toString(),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: isMarked
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isMarked
                                          ? primaryColor
                                          : theme.textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  if (isMarked)
                                    Icon(
                                      Icons.circle_outlined,
                                      size: 32,
                                      color: primaryColor,
                                    ),
                                ],
                              ),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
