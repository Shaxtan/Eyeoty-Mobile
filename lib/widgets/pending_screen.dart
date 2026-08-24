import 'package:flutter/material.dart';

/// Honest placeholder for screens that exist in the original web app's
/// navigation but whose source code was not shared during this
/// conversion (see README.md -> "Screens not yet ported"). This is
/// deliberately NOT hidden from navigation and NOT a fake/mocked
/// implementation — it clearly states its own status so nothing here
/// silently pretends to be finished.
class PendingScreen extends StatelessWidget {
  final String title;
  final String note;

  const PendingScreen({
    super.key,
    required this.title,
    this.note = 'This screen was not included in the source shared during '
        'conversion, so it has not been ported yet. Provide the matching '
        'React component and its API service to implement it.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.construction_outlined, size: 40, color: Colors.orange),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              note,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
