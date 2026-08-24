import 'package:flutter/foundation.dart';
import '../core/utils/load_status.dart';
import '../models/fleet_scan_result.dart';
import '../repositories/fleet_intelligence_repository.dart';

class FleetIntelligenceProvider extends ChangeNotifier {
  final FleetIntelligenceRepository _repo;
  FleetIntelligenceProvider(this._repo);

  LoadStatus status = LoadStatus.idle;
  FleetScanResult? scan;
  String? errorMessage;
  bool isRefetching = false;

  Future<void> runScan(String accountId, {bool isRefetch = false}) async {
    if (isRefetch) {
      isRefetching = true;
    } else {
      status = LoadStatus.loading;
    }
    notifyListeners();
    try {
      scan = await _repo.runScan(accountId: accountId);
      status = LoadStatus.loaded;
      errorMessage = null;
    } catch (e) {
      errorMessage = e.toString();
      status = LoadStatus.error;
    } finally {
      isRefetching = false;
      notifyListeners();
    }
  }
}