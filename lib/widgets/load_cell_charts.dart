import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/load_cell_reading.dart';

const _seriesColors = [Color(0xFF8B5CF6), Color(0xFF10B981), Color(0xFFF59E0B), Color(0xFFF43F5E)];

String _fmtTime(DateTime? d) {
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

/// Ported from LoadCellChart/LiveCellChart (both LoadCellReportPage.jsx
/// and LiveLoadPage.jsx render the exact same chart) - fl_chart
/// LineChart with area fill, approximating Recharts' AreaChart. Shared
/// between both screens since the chart logic is identical, only the
/// data source differs.
class LoadCellSeriesChart extends StatelessWidget {
  final List<LoadCellReading> data;
  final bool showData;
  final Color? avgColor;

  const LoadCellSeriesChart({super.key, required this.data, required this.showData, this.avgColor});

  LineChartBarData _line(double Function(LoadCellReading) get, Color color, {double width = 1.5}) {
    return LineChartBarData(
      spots: [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), get(data[i]))],
      isCurved: true,
      color: color,
      barWidth: width,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final series = <LineChartBarData>[];
    if (showData) {
      final getters = <double Function(LoadCellReading)>[
        (r) => r.v1.toDouble(),
        (r) => r.v2.toDouble(),
        (r) => r.v3.toDouble(),
        (r) => r.v4.toDouble(),
      ];
      for (var i = 0; i < 4; i++) {
        series.add(_line(getters[i], _seriesColors[i]));
      }
    }
    if (avgColor != null) {
      series.add(_line((r) => r.average.toDouble(), avgColor!, width: 2));
    }

    var maxY = 1.0;
    for (final s in series) {
      for (final spot in s.spots) {
        if (spot.y > maxY) maxY = spot.y;
      }
    }
    maxY *= 1.15;

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          lineBarsData: series,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, m) => Text(v.toStringAsFixed(0), style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (data.length / 4).clamp(1, data.length).toDouble(),
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_fmtTime(data[i].parsedTime), style: TextStyle(fontSize: 8, color: Colors.grey.shade400)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: true),
        ),
      ),
    );
  }
}

/// Ported from LoadPercentChart/LivePercentChart - fixed 0-100% range.
class LoadPercentSeriesChart extends StatelessWidget {
  final List<LoadCellReading> data;
  const LoadPercentSeriesChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final spots = [for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i].loadPercent.toDouble())];

    return SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF7C3AED),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: const Color(0xFF7C3AED).withValues(alpha: 0.15)),
            ),
          ],
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (v, m) => Text('${v.toInt()}%', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (data.length / 4).clamp(1, data.length).toDouble(),
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_fmtTime(data[i].parsedTime), style: TextStyle(fontSize: 8, color: Colors.grey.shade400)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: const LineTouchData(enabled: true),
        ),
      ),
    );
  }
}

/// Ported 1:1 from both pages' avgConfig derivation (identical logic in
/// both LoadCellReportPage.jsx and LiveLoadPage.jsx).
class AvgConfig {
  final Color stroke;
  final String label;
  final Color badgeBg;
  final Color badgeFg;
  const AvgConfig({required this.stroke, required this.label, required this.badgeBg, required this.badgeFg});
}

AvgConfig? avgConfigFor(List<LoadCellReading> data, bool showAvg) {
  if (!showAvg || data.isEmpty) return null;
  final last = data.last.average;
  if (last > 100) {
    return const AvgConfig(stroke: Color(0xFFEF4444), label: 'High Load', badgeBg: Color(0xFFFFE4E6), badgeFg: Color(0xFFBE123C));
  }
  if (last > 50) {
    return const AvgConfig(stroke: Color(0xFF10B981), label: 'Moderate Load', badgeBg: Color(0xFFD1FAE5), badgeFg: Color(0xFF047857));
  }
  return const AvgConfig(stroke: Color(0xFF2563EB), label: 'Low Load', badgeBg: Color(0xFFDBEAFE), badgeFg: Color(0xFF1D4ED8));
}