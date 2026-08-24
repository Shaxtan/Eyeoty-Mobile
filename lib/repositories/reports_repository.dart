import '../models/imei_option.dart';
import '../models/track_point.dart';
import '../models/distance_report_result.dart';
import '../models/working_hour_record.dart';
import '../models/account_summary_node.dart';
import '../services/reports_service.dart';

class ReportsRepository {
  final ReportsService _service;
  ReportsRepository(this._service);

  Future<List<ImeiOption>> getImeiDropdown(String accountId) => _service.getImeiDropdown(accountId);

  Future<DistanceReportResult> getDistanceReport({
    required String imei,
    required String startDate,
    required String endDate,
  }) =>
      _service.getDistanceReport(imei: imei, startDate: startDate, endDate: endDate);

  Future<List<TrackPoint>> getTrackPlayHistory({
    required String imei,
    required String startTime,
    required String endTime,
  }) =>
      _service.getTrackPlayHistory(imei: imei, startTime: startTime, endTime: endTime);

  Future<List<WorkingHourRecord>> getWorkingHourReport({
    required String imei,
    required String startDate,
    required String endDate,
  }) =>
      _service.getWorkingHourReport(imei: imei, startDate: startDate, endDate: endDate);

  Future<AccountSummaryNode?> getAccountSummary({
    required String accountId,
    required String startDate,
    required String endDate,
  }) =>
      _service.getAccountSummary(accountId: accountId, startDate: startDate, endDate: endDate);
}