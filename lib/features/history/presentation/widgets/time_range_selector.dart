import 'package:flutter/material.dart';
import '../../domain/time_window.dart';

class TimeRangeSelector extends StatelessWidget {
  final TimeWindow selectedWindow;
  final ValueChanged<TimeWindow> onSelected;

  const TimeRangeSelector({
    super.key,
    required this.selectedWindow,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TimeWindow.values.map((window) {
          final isSelected = window == selectedWindow;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(window.label),
              selected: isSelected,
              onSelected: (_) => onSelected(window),
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurface,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
