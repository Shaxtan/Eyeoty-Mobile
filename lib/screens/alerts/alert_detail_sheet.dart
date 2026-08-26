import 'package:flutter/material.dart';
import '../../models/alert_model.dart';
import '../../widgets/severity_badge.dart';

class AlertDetailSheet extends StatelessWidget {
  final FleetAlert alert;
  const AlertDetailSheet({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(alert.displayType,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
              ),
              SeverityBadge(severity: alert.severity),
            ],
          ),
          const SizedBox(height: 12),
          _row('Vehicle', alert.vehicleNumber ?? '\u2014'),
          _row('IMEI', alert.imei),
          _row('Triggered', alert.deviceTime ?? alert.createdOn),
          if (alert.address != null) _row('Location', alert.address!),
          if (alert.message != null) ...[
            const SizedBox(height: 8),
            Text(
              alert.message!,
              style: TextStyle(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                  fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
                width: 90,
                child: Text(label,
                    style:
                        TextStyle(color: Colors.grey.shade500, fontSize: 12))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}
