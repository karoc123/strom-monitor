import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/models/battery_reading.dart';
import '../providers/history_provider.dart';

class HistoryChart extends StatelessWidget {
  final List<BatteryReading> readings;
  final HistoryMetric metric;

  const HistoryChart({super.key, required this.readings, required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (readings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Colors.grey.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No data recorded for this time range',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < readings.length; i++) {
      final r = readings[i];
      double val;
      switch (metric) {
        case HistoryMetric.soc:
          val = r.soc.toDouble();
          break;
        case HistoryMetric.voltage:
          val = r.voltage;
          break;
        case HistoryMetric.current:
          val = r.current;
          break;
        case HistoryMetric.power:
          val = r.power;
          break;
      }
      spots.add(FlSpot(i.toDouble(), val));
    }

    Color lineColor;
    switch (metric) {
      case HistoryMetric.soc:
        lineColor = const Color(0xFF10B981);
        break;
      case HistoryMetric.voltage:
        lineColor = const Color(0xFF3B82F6);
        break;
      case HistoryMetric.current:
        lineColor = const Color(0xFFF59E0B);
        break;
      case HistoryMetric.power:
        lineColor = const Color(0xFF8B5CF6);
        break;
    }

    return AspectRatio(
      aspectRatio: 1.5,
      child: Padding(
        padding: const EdgeInsets.only(
          right: 18,
          left: 12,
          top: 24,
          bottom: 12,
        ),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _calculateGridInterval(),
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  interval: (readings.length / 4).clamp(1.0, 100.0),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= readings.length) {
                      return const SizedBox.shrink();
                    }
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      readings[index].timestamp,
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('HH:mm\ndd.MM').format(dt),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 42,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(
                        metric == HistoryMetric.voltage ? 1 : 0,
                      ),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.surfaceContainerHigh,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    final index = spot.x.toInt();
                    if (index < 0 || index >= readings.length) return null;
                    final reading = readings[index];
                    final timeStr = DateFormat('dd.MM HH:mm').format(
                      DateTime.fromMillisecondsSinceEpoch(reading.timestamp),
                    );
                    return LineTooltipItem(
                      '${spot.y.toStringAsFixed(2)} ${metric.unit}\n$timeStr',
                      TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                curveSmoothness: 0.2,
                color: lineColor,
                barWidth: 3,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      lineColor.withValues(alpha: 0.25),
                      lineColor.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _calculateGridInterval() {
    switch (metric) {
      case HistoryMetric.soc:
        return 20.0;
      case HistoryMetric.voltage:
        return 0.5;
      case HistoryMetric.current:
        return 2.0;
      case HistoryMetric.power:
        return 20.0;
    }
  }
}
