import '../models/fleet_scan_result.dart';
import '../services/fleet_intelligence_service.dart';

class FleetIntelligenceRepository {
  final FleetIntelligenceService _service;
  FleetIntelligenceRepository(this._service);

  Future<FleetScanResult> runScan({required String accountId}) =>
      _service.runScan(accountId: accountId);
}