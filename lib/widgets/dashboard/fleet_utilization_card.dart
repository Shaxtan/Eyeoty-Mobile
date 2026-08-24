import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/utilization_result.dart';
import '../../theme/app_colors.dart';

/// Real 7-day trend line, matching FleetUtilizationCard.jsx: big % headline,
/// up/down trend badge, and a line chart of daily utilization.
class FleetUtilizationCard extends StatelessWidget {
  final UtilizationResult? data;
  final bool loading;

  const FleetUtilizationCard({super.key, required this.data, required this.loading});

  @override
  Widget build(BuildContext context) {
    final points = data?.points ?? [];
    final avg = data?.avg ?? 0;
    final trend = data?.trend ?? 0;
    final isUp = trend >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fleet Utilization', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const Text('Last 7 days', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (points.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No utilization data yet.', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$avg%', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1)),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('Average Utilization', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUp ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isUp ? Icons.trending_up : Icons.trending_down,
                            size: 12, color: isUp ? Colors.green.shade700 : Colors.red.shade700),
                        const SizedBox(width: 3),
                        Text(
                          '${isUp ? '+' : ''}$trend%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isUp ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 140,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: 100,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (v) => FlLine(color: Colors.grey.shade100, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: 25,
                          getTitlesWidget: (v, meta) =>
                              Text('${v.toInt()}%', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (v, meta) {
                            final i = v.toInt();
                            if (i < 0 || i >= points.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(points[i].dayLabel,
                                  style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots
                            .map((s) => LineTooltipItem('${s.y.toInt()}%', const TextStyle(color: Colors.white, fontSize: 11)))
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (int i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].utilization.toDouble()),
                        ],
                        isCurved: true,
                        color: AppColors.primary,
                        barWidth: 2.5,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: AppColors.primarySoft),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
