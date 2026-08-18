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

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedWindow = ref.watch(selectedTimeWindowProvider);
    final selectedMetric = ref.watch(selectedMetricProvider);
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
              const SizedBox(height: 12),
              _buildMetricSelector(context, ref, selectedMetric),
              const SizedBox(height: 16),
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
                  data: (readings) =>
                      HistoryChart(readings: readings, metric: selectedMetric),
                  loading: () => const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (err, _) => SizedBox(
                    height: 240,
                    child: Center(child: Text('Error loading history: $err')),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              readingsAsync.maybeWhen(
                data: (readings) =>
                    _buildSummaryCards(readings, selectedMetric, theme),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSelector(
    BuildContext context,
    WidgetRef ref,
    HistoryMetric selectedMetric,
  ) {
    return SegmentedButton<HistoryMetric>(
      segments: HistoryMetric.values.map((metric) {
        return ButtonSegment<HistoryMetric>(
          value: metric,
          label: Text(metric.label),
        );
      }).toList(),
      selected: {selectedMetric},
      onSelectionChanged: (newSelection) {
        ref.read(selectedMetricProvider.notifier).state = newSelection.first;
      },
    );
  }

  Widget _buildSummaryCards(
    List<BatteryReading> readings,
    HistoryMetric metric,
    ThemeData theme,
  ) {
    if (readings.isEmpty) return const SizedBox.shrink();

    double min = double.infinity;
    double max = -double.infinity;
    double sum = 0;

    for (final r in readings) {
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
      }
      if (v < min) min = v;
      if (v > max) max = v;
      sum += v;
    }
    final avg = sum / readings.length;

    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            'Minimum',
            '${min.toStringAsFixed(1)} ${metric.unit}',
            theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatTile(
            'Average',
            '${avg.toStringAsFixed(1)} ${metric.unit}',
            theme,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatTile(
            'Maximum',
            '${max.toStringAsFixed(1)} ${metric.unit}',
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
        allowedExtensions: ['csv', 'json'],
      );

      if (pickedFile == null || pickedFile.path == null) {
        return;
      }

      final file = File(pickedFile.path!);
      final content = await file.readAsString();
      final isCsv = pickedFile.name.endsWith('.csv');

      final importedReadings = isCsv
          ? DataExporter.importFromCsv(content)
          : DataExporter.importFromJson(content);

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
