import 'package:flutter/material.dart';

/// Shared card for the Fleet Intelligence summary row (Data Quality
/// Score, Critical, Warnings, Total Findings). All four now go through
/// this ONE component instead of the Data Quality Score card being a
/// one-off inline layout while the other three used a separate widget
/// (formerly `StatTile`, renamed here to `SummaryStatCard` for clarity)
/// - that divergence was the likely source of the alignment
/// inconsistency between them. Uses an explicit Material + InkWell
/// (not the Card widget) so the tap ripple is correctly clipped to the
/// rounded corners, and forces `crossAxisAlignment: CrossAxisAlignment.center`
/// on the Row so the leading element and text are always vertically
/// centered together, never independently positioned.
class SummaryStatCard extends StatelessWidget {
  final Widget leading;
  final Widget content;
  final VoidCallback? onTap;

  const SummaryStatCard({
    super.key,
    required this.leading,
    required this.content,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon tile used as the `leading` widget for the Critical / Warnings /
/// Total Findings cards (Data Quality Score uses ScoreRing instead).
class SummaryStatIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;

  const SummaryStatIcon({super.key, required this.icon, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

/// Standard title + big value text block, used as `content` for the
/// three icon-based summary cards.
class SummaryStatText extends StatelessWidget {
  final String title;
  final String value;
  final bool loading;

  const SummaryStatText({super.key, required this.title, required this.value, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        loading
            ? Container(width: 40, height: 20, color: Colors.grey.shade100)
            : Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
      ],
    );
  }
}