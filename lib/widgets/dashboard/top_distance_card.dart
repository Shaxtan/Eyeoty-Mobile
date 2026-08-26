import 'package:flutter/material.dart';
import '../../models/top_distance_item.dart';

// Bar shade for each ranked row is interpolated between _rankStart
// (darkest — rank 1) and _rankEnd (lightest — last rank), so the fade
// is smooth end-to-end and stays consistent no matter how many rows
// the endpoint returns. Previously a hardcoded 5-shade palette was
// indexed with `i % palette.length`, which made the shade reset back
// to darkest at position 6 and give a stripe/rainbow effect.
const _rankStart = Color(0xFF1A73E8); // top rank — deepest blue
const _rankEnd = Color(0xFFC7DBF8); // bottom rank — softest blue

Color _rankColorFor(int index, int total) {
  if (total <= 1) return _rankStart;
  final t = index / (total - 1); // 0.0 for rank 1 → 1.0 for last rank
  return Color.lerp(_rankStart, _rankEnd, t) ?? _rankStart;
}

/// Matches TopDistanceCard.jsx's ranked list. The web version pairs a
/// bar chart with this list; on mobile a single ranked list with an
/// inline proportional bar carries the same information more compactly
/// (mobile-first adaptation, not a missing feature).
class TopDistanceCard extends StatelessWidget {
  final List<TopDistanceItem> data;
  final bool loading;
  final void Function(TopDistanceItem) onTapItem;
  final VoidCallback onViewFullReport;

  const TopDistanceCard({
    super.key,
    required this.data,
    required this.loading,
    required this.onTapItem,
    required this.onViewFullReport,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty
        ? 1
        : data.map((d) => d.valueKm).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Top by Distance',
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                ),
                TextButton(
                    onPressed: onViewFullReport,
                    child: const Text('Full Report',
                        style: TextStyle(fontSize: 12))),
              ],
            ),
            const Text('Today \u2014 by vehicle',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 10),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No distance data for today yet.',
                      style:
                          TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                ),
              )
            else
              ...data.asMap().entries.map((entry) {
                final i = entry.key;
                final d = entry.value;
                final color = _rankColorFor(i, data.length);
                final widthFactor = maxVal > 0 ? d.valueKm / maxVal : 0.0;
                return InkWell(
                  onTap: d.imei != null ? () => onTapItem(d) : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(d.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  Text('${d.valueKm} km',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: widthFactor.clamp(0.0, 1.0),
                                  minHeight: 4,
                                  backgroundColor: Colors.grey.shade100,
                                  valueColor: AlwaysStoppedAnimation(color),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
