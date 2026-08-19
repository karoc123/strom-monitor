import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/models/battery_reading.dart';
import '../../data/daily_yield_aggregator.dart';
import '../providers/history_provider.dart';

class HistoryChart extends StatelessWidget {
  final List<BatteryReading> readings;
  final HistoryMetric metric;

  const HistoryChart({super.key, required this.readings, required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (readings.isEmpty) {
      return _buildEmptyState(theme);
    }

    if (metric == HistoryMetric.solarYield) {
      return _buildDailyYieldBarChart(context, theme);
    }

    return _buildLineChart(context, theme);
  }

  Widget _buildEmptyState(ThemeData theme) {
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

  Widget _buildDailyYieldBarChart(BuildContext context, ThemeData theme) {
    final dailyYields = DailyYieldAggregator.aggregateByDay(readings);

    if (dailyYields.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Column(
            children: [
              Icon(
                Icons.solar_power_outlined,
                size: 48,
                color: Colors.grey.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                'No solar yield recorded for this time range',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final maxYieldVal = dailyYields
        .map((d) => d.yieldWh)
        .reduce((a, b) => math.max(a, b));
    final maxY = math.max(maxYieldVal * 1.2, 100.0);
    final rodWidth = (200.0 / dailyYields.length).clamp(6.0, 32.0);

    final barGroups = <BarChartGroupData>[];
    for (int i = 0; i < dailyYields.length; i++) {
      final dy = dailyYields[i];
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: dy.yieldWh,
              color: const Color(0xFF10B981),
              width: rodWidth,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      );
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
        child: BarChart(
          BarChartData(
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _calculateBarGridInterval(maxY),
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
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= dailyYields.length) {
                      return const SizedBox.shrink();
                    }
                    if (dailyYields.length > 8 &&
                        index % (dailyYields.length ~/ 4) != 0 &&
                        index != dailyYields.length - 1) {
                      return const SizedBox.shrink();
                    }
                    final dy = dailyYields[index];
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('dd.MM').format(dy.date),
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
                  interval: _calculateBarGridInterval(maxY),
                  getTitlesWidget: (value, meta) {
                    if (value == 0) {
                      return Text(
                        '0',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    if (value >= 1000) {
                      return Text(
                        '${(value / 1000).toStringAsFixed(1)}k',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    }
                    return Text(
                      value.toInt().toString(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            barTouchData: BarTouchData(
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => theme.colorScheme.surfaceContainerHigh,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final dy = dailyYields[group.x.toInt()];
                  final dateStr = DateFormat('EEE, dd.MM.yyyy').format(dy.date);
                  final yieldStr = dy.yieldWh >= 1000
                      ? '${(dy.yieldWh / 1000).toStringAsFixed(2)} kWh'
                      : '${dy.yieldWh.toStringAsFixed(0)} Wh';
                  return BarTooltipItem(
                    '$yieldStr\n$dateStr',
                    TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            barGroups: barGroups,
          ),
        ),
      ),
    );
  }

  double _calculateBarGridInterval(double maxY) {
    if (maxY > 5000) return 2000.0;
    if (maxY > 2000) return 1000.0;
    if (maxY > 800) return 400.0;
    if (maxY > 300) return 150.0;
    return 50.0;
  }

  Widget _buildLineChart(BuildContext context, ThemeData theme) {
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
        case HistoryMetric.solarPower:
          val = r.solarPower ?? 0.0;
          break;
        case HistoryMetric.solarYield:
          val = r.solarYieldToday ?? 0.0;
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
      case HistoryMetric.solarPower:
        lineColor = const Color(0xFFF59E0B);
        break;
      case HistoryMetric.solarYield:
        lineColor = const Color(0xFF10B981);
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
      case HistoryMetric.solarPower:
        return 20.0;
      case HistoryMetric.solarYield:
        return 200.0;
    }
  }
}
