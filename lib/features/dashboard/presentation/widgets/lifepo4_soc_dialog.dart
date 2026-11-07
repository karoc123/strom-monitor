import 'package:flutter/material.dart';

/// Single row entry representing a LiFePO4 SoC reference point based on industry standards.
class Lifepo4SocReferenceRow {
  final int soc;
  final String? sublabel;
  final double cellVoltage;
  final String status;
  final Color badgeColor;

  const Lifepo4SocReferenceRow({
    required this.soc,
    this.sublabel,
    required this.cellVoltage,
    required this.status,
    required this.badgeColor,
  });
}

/// Standard LiFePO4 cell voltage reference values according to:
/// https://www.lithium-battery-factory.com/de/lifepo4-cell-voltage-chart-comprehensive-guide/
const List<Lifepo4SocReferenceRow> lifepo4ReferenceRows = [
  Lifepo4SocReferenceRow(
    soc: 100,
    sublabel: 'Charge',
    cellVoltage: 3.65,
    status: '100% Ladung',
    badgeColor: Color(0xFF10B981),
  ),
  Lifepo4SocReferenceRow(
    soc: 100,
    sublabel: 'Rest',
    cellVoltage: 3.40,
    status: '100% Ruhe',
    badgeColor: Color(0xFF10B981),
  ),
  Lifepo4SocReferenceRow(
    soc: 90,
    cellVoltage: 3.35,
    status: '90%',
    badgeColor: Color(0xFF10B981),
  ),
  Lifepo4SocReferenceRow(
    soc: 80,
    cellVoltage: 3.32,
    status: '80%',
    badgeColor: Color(0xFF06B6D4),
  ),
  Lifepo4SocReferenceRow(
    soc: 70,
    cellVoltage: 3.30,
    status: '70%',
    badgeColor: Color(0xFF06B6D4),
  ),
  Lifepo4SocReferenceRow(
    soc: 60,
    cellVoltage: 3.27,
    status: '60%',
    badgeColor: Color(0xFF3B82F6),
  ),
  Lifepo4SocReferenceRow(
    soc: 50,
    cellVoltage: 3.26,
    status: '50% (Nominal)',
    badgeColor: Color(0xFF3B82F6),
  ),
  Lifepo4SocReferenceRow(
    soc: 40,
    cellVoltage: 3.25,
    status: '40%',
    badgeColor: Color(0xFF3B82F6),
  ),
  Lifepo4SocReferenceRow(
    soc: 30,
    cellVoltage: 3.22,
    status: '30%',
    badgeColor: Color(0xFFF59E0B),
  ),
  Lifepo4SocReferenceRow(
    soc: 20,
    cellVoltage: 3.20,
    status: '20% (Knick)',
    badgeColor: Color(0xFFF59E0B),
  ),
  Lifepo4SocReferenceRow(
    soc: 10,
    cellVoltage: 3.00,
    status: '10% (Reserve)',
    badgeColor: Color(0xFFF97316),
  ),
  Lifepo4SocReferenceRow(
    soc: 0,
    cellVoltage: 2.50,
    status: '0% (Cut-off)',
    badgeColor: Color(0xFFEF4444),
  ),
];

/// Dialog presenting an authoritative LiFePO4 State of Charge (SoC) reference table.
class Lifepo4SocDialog extends StatefulWidget {
  final double? currentVoltage;
  final int? cellCount;

  const Lifepo4SocDialog({super.key, this.currentVoltage, this.cellCount});

  @override
  State<Lifepo4SocDialog> createState() => _Lifepo4SocDialogState();
}

class _Lifepo4SocDialogState extends State<Lifepo4SocDialog> {
  late int _selectedSCount;

  @override
  void initState() {
    super.initState();
    final count = widget.cellCount;
    if (count == 1 || count == 4 || count == 8 || count == 16) {
      _selectedSCount = count!;
    } else {
      _selectedSCount = 4;
    }
  }

  int _findClosestRowIndex(double avgCellVoltage) {
    int closestIdx = 0;
    double minDiff = double.infinity;
    for (int i = 0; i < lifepo4ReferenceRows.length; i++) {
      final diff = (lifepo4ReferenceRows[i].cellVoltage - avgCellVoltage).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenSize = MediaQuery.sizeOf(context);
    final currentVolt = widget.currentVoltage;
    final int activeCellCount =
        (widget.cellCount != null && widget.cellCount! > 0)
        ? widget.cellCount!
        : _selectedSCount;
    final double? avgCellVolt = currentVolt != null && activeCellCount > 0
        ? currentVolt / activeCellCount
        : null;
    final int? activeRowIndex = avgCellVolt != null
        ? _findClosestRowIndex(avgCellVolt)
        : null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenSize.height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.table_chart_outlined,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LiFePO4 SoC Reference',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Cell & Pack Voltage Chart (OCV / Ruhespannung)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Close',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Scrollable Body
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Live Battery Telemetry Banner (if available)
                      if (currentVolt != null && avgCellVolt != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.my_location,
                                size: 16,
                                color: Color(0xFF3B82F6),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Live: ${currentVolt.toStringAsFixed(2)} V (${avgCellVolt.toStringAsFixed(3)} V/Cell • ${activeCellCount}S)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (activeRowIndex != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: lifepo4ReferenceRows[activeRowIndex]
                                        .badgeColor
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '~${lifepo4ReferenceRows[activeRowIndex].soc}%',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          lifepo4ReferenceRows[activeRowIndex]
                                              .badgeColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Pack Multiplier Selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pack Configuration:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(value: 1, label: Text('1S')),
                                ButtonSegment(
                                  value: 4,
                                  label: Text('4S (12V)'),
                                ),
                                ButtonSegment(
                                  value: 8,
                                  label: Text('8S (24V)'),
                                ),
                                ButtonSegment(
                                  value: 16,
                                  label: Text('16S (48V)'),
                                ),
                              ],
                              selected: {_selectedSCount},
                              showSelectedIcon: false,
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(horizontal: 4),
                                ),
                              ),
                              onSelectionChanged: (set) {
                                setState(() {
                                  _selectedSCount = set.first;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Reference Parameters Summary (Lade- & Systemgrenzen)
                      _buildChargingLimitsCard(theme),
                      const SizedBox(height: 12),

                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 46,
                              child: Text(
                                'SoC',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 58,
                              child: Text(
                                'Cell (V)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Pack (${_selectedSCount}S)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(
                              width: 85,
                              child: Text(
                                'Zustand',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Table Rows
                      for (int i = 0; i < lifepo4ReferenceRows.length; i++) ...[
                        _buildTableRow(
                          context,
                          theme,
                          lifepo4ReferenceRows[i],
                          isCurrentRow: activeRowIndex == i,
                        ),
                        if (i < lifepo4ReferenceRows.length - 1)
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.35,
                            ),
                          ),
                      ],
                      const SizedBox(height: 12),

                      // Educational Callout Note
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Hinweis: LiFePO4 hat zwischen 20% und 90% eine extrem flache Spannungskurve (nur ca. 0,07 V Unterschied pro Zelle). Diese Tabelle gibt die Ruhespannung (OCV) nach mind. 30–60 Min. ohne Last/Ladung wieder.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 10.5,
                                  height: 1.3,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Close Action
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChargingLimitsCard(ThemeData theme) {
    final double bulk = 3.65 * _selectedSCount;
    final double floatV = 3.375 * _selectedSCount;
    final double nominal = 3.20 * _selectedSCount;
    final double cutoff = 2.50 * _selectedSCount;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Lade- & Systemgrenzen (${_selectedSCount}S)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'Referenz',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildLimitItem(
                  'Bulk / Laden:',
                  '${bulk.toStringAsFixed(2)} V',
                  theme,
                  const Color(0xFF10B981),
                ),
              ),
              Expanded(
                child: _buildLimitItem(
                  'Float / Erhaltung:',
                  '${floatV.toStringAsFixed(2)} V',
                  theme,
                  const Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildLimitItem(
                  'Nennspannung:',
                  '${nominal.toStringAsFixed(1)} V',
                  theme,
                  const Color(0xFF3B82F6),
                ),
              ),
              Expanded(
                child: _buildLimitItem(
                  'Entladeschluss:',
                  '${cutoff.toStringAsFixed(1)} V',
                  theme,
                  const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLimitItem(
    String label,
    String value,
    ThemeData theme,
    Color valueColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow(
    BuildContext context,
    ThemeData theme,
    Lifepo4SocReferenceRow row, {
    required bool isCurrentRow,
  }) {
    final packVolt = row.cellVoltage * _selectedSCount;

    return Container(
      decoration: BoxDecoration(
        color: isCurrentRow
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // SoC Column
          SizedBox(
            width: 46,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${row.soc}%',
                  style: TextStyle(
                    fontWeight: isCurrentRow
                        ? FontWeight.bold
                        : FontWeight.w600,
                    fontSize: 12,
                    color: isCurrentRow
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                if (row.sublabel != null)
                  Text(
                    row.sublabel!,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      color: isCurrentRow
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Cell Voltage Column
          SizedBox(
            width: 58,
            child: Text(
              '${row.cellVoltage.toStringAsFixed(2)} V',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: isCurrentRow ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // Pack Voltage Column
          Expanded(
            child: Text(
              '${packVolt.toStringAsFixed(2)} V',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: isCurrentRow ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // State / Range Badge
          SizedBox(
            width: 85,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: row.badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isCurrentRow ? row.badgeColor : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Text(
                  row.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: row.badgeColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
