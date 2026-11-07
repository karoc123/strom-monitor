import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Circular/Arc gauge visualizing State of Charge (SoC).
class SocGauge extends StatelessWidget {
  final int soc;
  final double voltage;
  final double current;
  final double power;
  final bool isCharging;
  final bool isDischarging;
  final VoidCallback? onVoltageTap;

  const SocGauge({
    super.key,
    required this.soc,
    required this.voltage,
    required this.current,
    required this.power,
    required this.isCharging,
    required this.isDischarging,
    this.onVoltageTap,
  });

  Color _getStatusColor(BuildContext context) {
    if (isCharging) return const Color(0xFF10B981); // Emerald Green
    if (isDischarging) {
      if (soc <= 20) return const Color(0xFFEF4444); // Red
      return const Color(0xFFF59E0B); // Amber
    }
    return Theme.of(context).colorScheme.primary;
  }

  String _getStatusText() {
    if (isCharging) {
      return 'Charging (+${current.abs().toStringAsFixed(1)} A)';
    }
    if (isDischarging) {
      return 'Discharging (-${current.abs().toStringAsFixed(1)} A)';
    }
    return 'Standby';
  }

  IconData _getStatusIcon() {
    if (isCharging) return Icons.bolt;
    if (isDischarging) return Icons.power_outlined;
    return Icons.pause_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);
    final theme = Theme.of(context);

    return Center(
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(240, 240),
              painter: _GaugePainter(
                soc: soc,
                progressColor: statusColor,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getStatusIcon(), size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        _getStatusText(),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$soc',
                      style: theme.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                      ),
                    ),
                    Text(
                      '%',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onVoltageTap,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${voltage.toStringAsFixed(2)} V',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        if (onVoltageTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.info_outline,
                            size: 13,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Text(
                  isCharging
                      ? '+${power.abs().toStringAsFixed(1)} W'
                      : isDischarging
                      ? '-${power.abs().toStringAsFixed(1)} W'
                      : '${power.abs().toStringAsFixed(1)} W',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isCharging
                        ? const Color(0xFF10B981)
                        : isDischarging
                        ? const Color(0xFFF59E0B)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int soc;
  final Color progressColor;
  final Color backgroundColor;

  _GaugePainter({
    required this.soc,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 14.0;

    // Start angle at bottom-left (135 degrees = 3/4 pi) and sweep 270 degrees (1.5 pi)
    const startAngle = 0.75 * math.pi;
    const sweepAngle = 1.5 * math.pi;

    // Background track
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Progress arc
    final progressSweep = sweepAngle * (soc.clamp(0, 100) / 100.0);
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      progressSweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.soc != soc ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.backgroundColor != backgroundColor;
}
