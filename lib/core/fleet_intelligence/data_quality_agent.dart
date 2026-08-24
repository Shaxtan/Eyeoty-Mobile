import '../../models/fleet_scan_result.dart';
import 'agent_helpers.dart';

const _agent = 'data-quality';
const _movingSpeedKmh = 3;

class DataQualityResult {
  final List<FleetFinding> findings;
  final QualityStats stats;
  DataQualityResult({required this.findings, required this.stats});
}

/// Ported 1:1 from dataQuality.agent.js (Agent #6). Pure function — no
/// network, safe to run on every refresh, exactly like the original.
DataQualityResult runDataQualityAgent(List<Map<String, dynamic>> records, {int? now}) {
  final nowMs = now ?? DateTime.now().millisecondsSinceEpoch;
  final findings = <FleetFinding>[];
  final seen = <String, bool>{};

  final total = records.length;
  var corruptTimestamp = 0;
  var ignContradiction = 0;
  var missingFieldsCount = 0;
  var invalidCoords = 0;
  var duplicates = 0;
  var clean = 0;

  for (final r in records) {
    final imei = (r['imei'] ?? r['deviceId'])?.toString();
    final vehnum = (r['vehicleNumber'] ?? r['vehnum'] ?? r['name'])?.toString();
    final accId = (r['accId'] ?? r['accid'])?.toString();
    var recordHasIssue = false;

    // 1. Missing critical fields
    final missing = <String>[];
    if (imei == null || imei.isEmpty) missing.add('imei');
    if (r['lat'] == null && r['latitude'] == null) missing.add('lat');
    if (r['lng'] == null && r['longitude'] == null) missing.add('lng');
    if (r['deviceTime'] == null && r['devTs'] == null && r['ts'] == null) missing.add('deviceTime');
    if (missing.isNotEmpty) {
      missingFieldsCount++;
      recordHasIssue = true;
      findings.add(FleetFinding.make(
        agent: _agent,
        severity: Severity.warning,
        code: 'MISSING_FIELDS',
        title: 'Missing critical fields',
        detail: 'Record is missing: ${missing.join(', ')}.',
        imei: imei,
        vehnum: vehnum,
        accId: accId,
        value: missing.join(','),
      ));
    }

    // 2. Corrupt timestamp (the 2041 bug)
    final rawTs = r['deviceTime'] ?? r['devTs'] ?? r['ts'] ?? r['dateTime'];
    final epoch = parseTs(rawTs);
    final tsReason = timestampSanity(epoch, nowMs);
    if (tsReason != null) {
      corruptTimestamp++;
      recordHasIssue = true;
      final human = tsReason == 'future'
          ? 'Timestamp is in the future ($rawTs)'
          : tsReason == 'ancient'
              ? 'Timestamp is implausibly old ($rawTs)'
              : 'Timestamp could not be parsed ($rawTs)';
      findings.add(FleetFinding.make(
        agent: _agent,
        severity: Severity.critical,
        code: 'CORRUPT_TIMESTAMP',
        title: 'Corrupt device timestamp',
        detail: '$human. Downstream trip/alert times will be wrong.',
        imei: imei,
        vehnum: vehnum,
        accId: accId,
        value: '$rawTs',
        expected: 'within \u00b11 day of now',
        raw: {'deviceTime': r['deviceTime'], 'createdOn': r['createdOn']},
      ));
    }

    // 3. Ignition contradiction (ign="N" while moving)
    final speed = numOf(r['speed']);
    final ign = (r['ign'] ?? '').toString().toUpperCase();
    if (ign == 'N' && speed > _movingSpeedKmh) {
      ignContradiction++;
      recordHasIssue = true;
      findings.add(FleetFinding.make(
        agent: _agent,
        severity: Severity.warning,
        code: 'IGN_CONTRADICTION',
        title: 'Ignition off while moving',
        detail: 'Device reports ign="N" but speed is $speed km/h. Status logic should trust speed, not the ignition flag.',
        imei: imei,
        vehnum: vehnum,
        accId: accId,
        value: '$speed km/h',
        expected: 'ign="Y" when moving',
      ));
    }

    // 4. Invalid coordinates
    final lat = numOf(r['lat'] ?? r['latitude'], double.nan);
    final lng = numOf(r['lng'] ?? r['longitude'], double.nan);
    if (!missing.contains('lat') && !missing.contains('lng')) {
      if (!isValidLat(lat) || !isValidLng(lng)) {
        invalidCoords++;
        recordHasIssue = true;
        findings.add(FleetFinding.make(
          agent: _agent,
          severity: Severity.warning,
          code: 'INVALID_COORDS',
          title: 'Invalid GPS coordinates',
          detail: 'Coordinates ($lat, $lng) are out of range or null-island (0,0).',
          imei: imei,
          vehnum: vehnum,
          accId: accId,
          value: '$lat,$lng',
        ));
      }
    }

    // 5. Duplicate record
    if (imei != null && imei.isNotEmpty && rawTs != null) {
      final key = '$imei|$rawTs';
      if (seen.containsKey(key)) {
        duplicates++;
        recordHasIssue = true;
        findings.add(FleetFinding.make(
          agent: _agent,
          severity: Severity.info,
          code: 'DUPLICATE',
          title: 'Duplicate telemetry record',
          detail: 'Same IMEI + deviceTime ($rawTs) appears more than once in this batch.',
          imei: imei,
          vehnum: vehnum,
          accId: accId,
          value: '$rawTs',
        ));
      } else {
        seen[key] = true;
      }
    }

    if (!recordHasIssue) clean++;
  }

  final score = total > 0 ? ((clean / total) * 100).round() : 100;

  return DataQualityResult(
    findings: findings,
    stats: QualityStats(
      total: total,
      corruptTimestamp: corruptTimestamp,
      ignContradiction: ignContradiction,
      missingFields: missingFieldsCount,
      invalidCoords: invalidCoords,
      duplicates: duplicates,
      clean: clean,
      score: score,
    ),
  );
}