import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/database/models/battery_reading.dart';
import '../../data/daily_yield_aggregator.dart';
import '../../domain/time_window.dart';
import '../providers/history_provider.dart';

class HistoryChart extends StatelessWidget {
  final List<BatteryReading> readings;
  final HistoryMetric metric;
  final TimeWindow? timeWindow;

  const HistoryChart({
    super.key,
    required this.readings,
    required this.metric,
    this.timeWindow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (readings.isEmpty) {
      return _buildEmptyState(theme);
    }

    if (metric == HistoryMetric.solarYield) {
      return _buildDailyYieldBarChart(context, theme);
    }

    if (metric == HistoryMetric.solarPower) {
      final hasSolarData = readings.any((r) => r.solarPower != null);
      if (!hasSolarData) {
        return _buildSolarEmptyState(theme);
      }
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

  Widget _buildSolarEmptyState(ThemeData theme) {
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
              'No solar power recorded for this time range',
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
    final sortedReadings = List<BatteryReading>.from(readings)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final int windowStartMs;
    final int windowEndMs;
    if (timeWindow != null && timeWindow != TimeWindow.all) {
      windowStartMs = timeWindow!.getStartTimestampMs();
      windowEndMs = DateTime.now().millisecondsSinceEpoch;
    } else {
      windowStartMs = sortedReadings.first.timestamp;
      windowEndMs = math.max(
        sortedReadings.last.timestamp,
        windowStartMs + 3600 * 1000,
      );
    }

    final startDt = DateTime.fromMillisecondsSinceEpoch(windowStartMs);
    final midnightStartDt = DateTime(startDt.year, startDt.month, startDt.day);
    final baseTimestampMs = midnightStartDt.millisecondsSinceEpoch;

    final minX = (windowStartMs - baseTimestampMs) / 1000.0;
    final maxX = math.max(
      (windowEndMs - baseTimestampMs) / 1000.0,
      minX + 60.0,
    );
    final totalSpanSeconds = maxX - minX;

    final spots = <FlSpot>[];
    BatteryReading? prevReading;

    for (int i = 0; i < sortedReadings.length; i++) {
      final r = sortedReadings[i];
      final x = (r.timestamp - baseTimestampMs) / 1000.0;

      double? val;
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
          val = r.solarPower;
          break;
        case HistoryMetric.solarYield:
          val = r.solarYieldToday;
          break;
      }

      if (val == null) {
        if (spots.isNotEmpty && !spots.last.isNull()) {
          spots.add(FlSpot.nullSpot);
        }
        continue;
      }

      // Break line across disconnections/missing data > 20 minutes (1200s)
      if (prevReading != null) {
        final gapSeconds = (r.timestamp - prevReading.timestamp) / 1000.0;
        if (gapSeconds > 1200 && spots.isNotEmpty && !spots.last.isNull()) {
          spots.add(FlSpot.nullSpot);
        }
      }

      spots.add(FlSpot(x, val));
      prevReading = r;
    }

    while (spots.isNotEmpty && spots.last.isNull()) {
      spots.removeLast();
    }

    final validSpots = spots.where((s) => !s.isNull()).toList();
    if (validSpots.isEmpty) {
      return metric == HistoryMetric.solarPower
          ? _buildSolarEmptyState(theme)
          : _buildEmptyState(theme);
    }

    final yConfig = _calculateYAxisConfig(metric, validSpots);
    final xAxisConfig = _calculateXAxisConfig(timeWindow, totalSpanSeconds);
    final xInterval = xAxisConfig.interval;

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
            minX: minX,
            maxX: maxX,
            minY: yConfig.minY,
            maxY: yConfig.maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: yConfig.interval,
              verticalInterval: xInterval,
              getDrawingHorizontalLine: (value) => FlLine(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                strokeWidth: 1,
              ),
              getDrawingVerticalLine: (value) {
                final diff = (value % xInterval).abs();
                if (diff > 1.0 && (xInterval - diff) > 1.0) {
                  return const FlLine(color: Colors.transparent);
                }
                final dt = DateTime.fromMillisecondsSinceEpoch(
                  baseTimestampMs + (value * 1000).round(),
                );
                final isMidnight = dt.hour == 0 && dt.minute == 0;
                return FlLine(
                  color: isMidnight
                      ? theme.colorScheme.outline.withValues(alpha: 0.35)
                      : theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.15,
                        ),
                  strokeWidth: isMidnight ? 1.5 : 1,
                  dashArray: isMidnight ? null : const [4, 4],
                );
              },
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
                  reservedSize: 36,
                  interval: xInterval,
                  getTitlesWidget: (value, meta) {
                    final diff = (value % xInterval).abs();
                    if (diff > 1.0 && (xInterval - diff) > 1.0) {
                      return const SizedBox.shrink();
                    }

                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      baseTimestampMs + (value * 1000).round(),
                    );

                    if (xAxisConfig.is24h) {
                      final isMidnight = dt.hour == 0 && dt.minute == 0;
                      if (isMidnight) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            '00:00\n${DateFormat('dd.MM').format(dt)}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          DateFormat('HH:mm').format(dt),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    if (xAxisConfig.is7d) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          DateFormat('E\ndd.MM').format(dt),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        DateFormat('dd.MM').format(dt),
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
                  interval: yConfig.interval,
                  getTitlesWidget: (value, meta) {
                    if (value < yConfig.minY || value > yConfig.maxY) {
                      return const SizedBox.shrink();
                    }
                    final formatted = metric == HistoryMetric.voltage
                        ? value.toStringAsFixed(1)
                        : (value >= 1000
                              ? '${(value / 1000).toStringAsFixed(1)}k'
                              : value.toStringAsFixed(0));
                    return Text(
                      formatted,
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
                    if (spot.isNull()) return null;
                    final dt = DateTime.fromMillisecondsSinceEpoch(
                      baseTimestampMs + (spot.x * 1000).round(),
                    );
                    final timeStr = DateFormat('dd.MM HH:mm').format(dt);
                    final valFormatted = spot.y.toStringAsFixed(
                      metric == HistoryMetric.voltage ? 2 : 1,
                    );
                    return LineTooltipItem(
                      '$valFormatted ${metric.unit}\n$timeStr',
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
                curveSmoothness: 0.15,
                preventCurveOverShooting: true,
                color: lineColor,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: validSpots.length <= 3,
                  checkToShowDot: (spot, barData) => !spot.isNull(),
                ),
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

  ({double interval, bool is24h, bool is7d}) _calculateXAxisConfig(
    TimeWindow? window,
    double totalSpanSeconds,
  ) {
    if (window == TimeWindow.hours24 ||
        (window == null && totalSpanSeconds <= 90000)) {
      return (interval: 14400.0, is24h: true, is7d: false); // 4 hours
    }
    if (window == TimeWindow.days7 ||
        (window == null && totalSpanSeconds <= 86400 * 8)) {
      return (interval: 86400.0, is24h: false, is7d: true); // 1 day
    }
    return (interval: 5 * 86400.0, is24h: false, is7d: false); // 5 days
  }

  ({double minY, double maxY, double interval}) _calculateYAxisConfig(
    HistoryMetric metric,
    List<FlSpot> validSpots,
  ) {
    if (validSpots.isEmpty) {
      return (minY: 0.0, maxY: 100.0, interval: 20.0);
    }

    final values = validSpots.map((s) => s.y).toList();
    final dataMin = values.reduce(math.min);
    final dataMax = values.reduce(math.max);

    switch (metric) {
      case HistoryMetric.solarPower:
        final maxY = _calculateSolarMaxY(dataMax);
        final interval = _calculateSolarGridInterval(maxY);
        return (minY: 0.0, maxY: maxY, interval: interval);

      case HistoryMetric.soc:
        return (minY: 0.0, maxY: 100.0, interval: 20.0);

      case HistoryMetric.voltage:
        final minY = (dataMin - 0.2).clamp(10.0, 16.0);
        final maxY = (dataMax + 0.2).clamp(11.0, 16.0);
        return (minY: minY, maxY: maxY, interval: 0.5);

      case HistoryMetric.current:
        final minY = math.min(dataMin * 1.15, 0.0);
        final maxY = math.max(dataMax * 1.15, 2.0);
        final span = maxY - minY;
        final interval = span > 40 ? 10.0 : (span > 15 ? 5.0 : 2.0);
        return (minY: minY, maxY: maxY, interval: interval);

      case HistoryMetric.power:
        final minY = math.min(dataMin * 1.15, 0.0);
        final maxY = math.max(dataMax * 1.15, 20.0);
        final span = maxY - minY;
        final interval = span > 400 ? 100.0 : (span > 150 ? 50.0 : 20.0);
        return (minY: minY, maxY: maxY, interval: interval);

      case HistoryMetric.solarYield:
        final maxY = math.max(dataMax * 1.2, 100.0);
        final interval = _calculateBarGridInterval(maxY);
        return (minY: 0.0, maxY: maxY, interval: interval);
    }
  }

  double _calculateSolarMaxY(double dataMax) {
    if (dataMax <= 80) return 100.0;
    if (dataMax <= 170) return 200.0;
    if (dataMax <= 260) return 300.0;
    if (dataMax <= 420) return 500.0;
    if (dataMax <= 700) return 800.0;
    return ((dataMax * 1.15) / 100).ceil() * 100.0;
  }

  double _calculateSolarGridInterval(double maxY) {
    if (maxY > 800) return 200.0;
    if (maxY > 400) return 100.0;
    if (maxY > 200) return 50.0;
    if (maxY > 100) return 25.0;
    return 20.0;
  }
}
