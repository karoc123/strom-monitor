import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/database/models/battery_reading.dart';
import '../../../../core/providers/database_provider.dart';
import '../data/data_exporter.dart';
import 'providers/history_provider.dart';
import 'widgets/history_chart.dart';
import 'widgets/time_range_selector.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  HistoryMetric _selectedBatteryMetric = HistoryMetric.soc;
  HistoryMetric _selectedSolarMetric = HistoryMetric.solarPower;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedWindow = ref.watch(selectedTimeWindowProvider);
    final readingsAsync = ref.watch(historyReadingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Historical Analytics',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Data (CSV/JSON)',
            onPressed: () => _showExportDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import Backup',
            onPressed: () => _importBackup(context, ref),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(historyReadingsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TimeRangeSelector(
                selectedWindow: selectedWindow,
                onSelected: (window) {
                  ref.read(selectedTimeWindowProvider.notifier).state = window;
                },
              ),
              const SizedBox(height: 16),

              // ==================== GRAPH 1: BATTERIE VERLAUF ====================
              _buildSectionTitle(
                'Battery History (JBD BMS)',
                Icons.battery_charging_full,
                const Color(0xFF3B82F6),
                theme,
              ),
              const SizedBox(height: 8),
              _buildBatteryMetricSelector(_selectedBatteryMetric),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: readingsAsync.when(
                  data: (readings) => HistoryChart(
                    readings: readings,
                    metric: _selectedBatteryMetric,
                  ),
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SizedBox(
                    height: 200,
                    child: Center(child: Text('Error loading history: $err')),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              readingsAsync.maybeWhen(
                data: (readings) => _buildBatterySummaryCards(
                  readings,
                  _selectedBatteryMetric,
                  theme,
                ),
                orElse: () => const SizedBox.shrink(),
              ),

              const SizedBox(height: 24),

              // ==================== GRAPH 2: SOLAR VERLAUF (VICTRON MPPT) ====================
              _buildSectionTitle(
                'Solar History (Victron MPPT)',
                Icons.solar_power,
                const Color(0xFFF59E0B),
                theme,
              ),
              const SizedBox(height: 8),
              _buildSolarMetricSelector(_selectedSolarMetric),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
                child: readingsAsync.when(
                  data: (readings) => HistoryChart(
                    readings: readings,
                    metric: _selectedSolarMetric,
                  ),
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SizedBox(
                    height: 200,
                    child: Center(
                      child: Text('Error loading solar history: $err'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              readingsAsync.maybeWhen(
                data: (readings) => _buildSolarSummaryCards(
                  readings,
                  _selectedSolarMetric,
                  theme,
                ),
                orElse: () => const SizedBox.shrink(),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryMetricSelector(HistoryMetric selectedMetric) {
    const metrics = [
      HistoryMetric.soc,
      HistoryMetric.current,
      HistoryMetric.power,
      HistoryMetric.voltage,
    ];

    return SegmentedButton<HistoryMetric>(
      segments: metrics.map((m) {
        return ButtonSegment<HistoryMetric>(value: m, label: Text(m.label));
      }).toList(),
      selected: {selectedMetric},
      onSelectionChanged: (newSelection) {
        setState(() => _selectedBatteryMetric = newSelection.first);
      },
    );
  }

  Widget _buildSolarMetricSelector(HistoryMetric selectedMetric) {
    const metrics = [HistoryMetric.solarPower, HistoryMetric.solarYield];

    return SegmentedButton<HistoryMetric>(
      segments: metrics.map((m) {
        return ButtonSegment<HistoryMetric>(value: m, label: Text(m.label));
      }).toList(),
      selected: {selectedMetric},
      onSelectionChanged: (newSelection) {
        setState(() => _selectedSolarMetric = newSelection.first);
      },
    );
  }

  Widget _buildBatterySummaryCards(
    List<BatteryReading> readings,
    HistoryMetric metric,
    ThemeData theme,
  ) {
    if (readings.isEmpty) return const SizedBox.shrink();

    // For battery SoC/Voltage/Current/Power, filter out pure solar readings if BMS readings exist
    final relevantReadings =
        (metric == HistoryMetric.soc ||
            metric == HistoryMetric.voltage ||
            metric == HistoryMetric.current ||
            metric == HistoryMetric.power)
        ? readings
              .where(
                (r) =>
                    r.cellVoltage1 != null ||
                    r.tempBms != null ||
                    r.cycles != null ||
                    r.soc > 0,
              )
              .toList()
        : readings;

    final targetReadings = relevantReadings.isNotEmpty
        ? relevantReadings
        : readings;

    double min = double.infinity;
    double max = -double.infinity;
    double sum = 0;

    for (final r in targetReadings) {
      double v;
      switch (metric) {
        case HistoryMetric.soc:
          v = r.soc.toDouble();
          break;
        case HistoryMetric.voltage:
          v = r.voltage;
          break;
        case HistoryMetric.current:
          v = r.current;
          break;
        case HistoryMetric.power:
          v = r.power;
          break;
        default:
          v = 0;
      }
      if (v < min) min = v;
      if (v > max) max = v;
      sum += v;
    }
    final avg = sum / targetReadings.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            'Min',
            '${min.toStringAsFixed(1)} ${metric.unit}',
            theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatTile(
            'Avg',
            '${avg.toStringAsFixed(1)} ${metric.unit}',
            theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatTile(
            'Max',
            '${max.toStringAsFixed(1)} ${metric.unit}',
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildSolarSummaryCards(
    List<BatteryReading> readings,
    HistoryMetric metric,
    ThemeData theme,
  ) {
    final solarReadings = readings
        .where((r) => r.solarPower != null || r.solarYieldToday != null)
        .toList();
    if (solarReadings.isEmpty) {
      return const SizedBox.shrink();
    }

    double peakPower = 0;
    double maxYield = 0;
    double powerSum = 0;
    int powerCount = 0;

    for (final r in solarReadings) {
      if (r.solarPower != null) {
        if (r.solarPower! > peakPower) peakPower = r.solarPower!;
        powerSum += r.solarPower!;
        powerCount++;
      }
      if (r.solarYieldToday != null && r.solarYieldToday! > maxYield) {
        maxYield = r.solarYieldToday!;
      }
    }

    final avgPower = powerCount > 0 ? powerSum / powerCount : 0.0;

    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            'Peak Power',
            '${peakPower.toStringAsFixed(0)} W',
            theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatTile(
            'Max Yield',
            maxYield >= 1000
                ? '${(maxYield / 1000).toStringAsFixed(2)} kWh'
                : '${maxYield.toStringAsFixed(0)} Wh',
            theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatTile(
            'Avg Solar',
            '${avgPower.toStringAsFixed(0)} W',
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(String label, String value, ThemeData theme) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExportDialog(BuildContext context, WidgetRef ref) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Export Telemetry Data',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Export full historical battery readings via Android Share.',
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.table_chart_outlined,
                    color: Colors.green,
                  ),
                  title: const Text('Export as CSV'),
                  subtitle: const Text(
                    'Standard spreadsheet format (timestamp, voltage, SoC, current...)',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportData(context, ref, isCsv: true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.code_outlined, color: Colors.blue),
                  title: const Text('Export as JSON'),
                  subtitle: const Text(
                    'Structured JSON array for backups or data processing',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _exportData(context, ref, isCsv: false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportData(
    BuildContext context,
    WidgetRef ref, {
    required bool isCsv,
  }) async {
    try {
      final dao = ref.read(readingDaoProvider);
      final allReadings = await dao.getAllReadings();

      if (allReadings.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No historical data available to export.'),
            ),
          );
        }
        return;
      }

      final content = isCsv
          ? DataExporter.exportToCsv(allReadings)
          : DataExporter.exportToJson(allReadings);

      final tempDir = await getTemporaryDirectory();
      final ext = isCsv ? 'csv' : 'json';
      final fileName =
          'strommonitor_backup_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(content);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Ström Monitor Telemetry Export',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    try {
      final pickedFile = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['csv', 'json', 'txt'],
      );

      if (pickedFile == null || pickedFile.path == null) {
        return;
      }

      final file = File(pickedFile.path!);
      final content = await file.readAsString();
      final importedReadings = DataExporter.importFromText(content);

      if (importedReadings.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No valid records found in selected file.'),
            ),
          );
        }
        return;
      }

      final dao = ref.read(readingDaoProvider);
      await dao.insertReadingsBatch(importedReadings);
      ref.invalidate(historyReadingsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${importedReadings.length} records!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}
