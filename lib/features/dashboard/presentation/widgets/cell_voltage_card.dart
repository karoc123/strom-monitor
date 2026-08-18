import 'package:flutter/material.dart';

/// Card showing individual cell voltages and cell delta (balance).
class CellVoltageCard extends StatelessWidget {
  final List<double> cellVoltages;

  const CellVoltageCard({super.key, required this.cellVoltages});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (cellVoltages.isEmpty) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              'No cell voltage telemetry available',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    double minV = cellVoltages.first;
    double maxV = cellVoltages.first;
    for (final v in cellVoltages) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final deltaMv = ((maxV - minV) * 1000).round();

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cell Voltages (4S)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: deltaMv <= 20
                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Δ $deltaMv mV',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: deltaMv <= 20
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(cellVoltages.length, (index) {
              final volt = cellVoltages[index];
              // LiFePO4 typical range 2.5V to 3.65V
              final normalized = ((volt - 2.8) / (3.65 - 2.8)).clamp(0.0, 1.0);
              final isHighest = volt == maxV && cellVoltages.length > 1;
              final isLowest = volt == minV && cellVoltages.length > 1;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Cell ${index + 1}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (isHighest)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  '(Max)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            if (isLowest)
                              Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Text(
                                  '(Min)',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          '${volt.toStringAsFixed(3)} V',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: normalized,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: isLowest
                            ? const Color(0xFFF59E0B)
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
