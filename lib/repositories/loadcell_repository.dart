import '../models/load_cell_reading.dart';
import '../services/loadcell_service.dart';

class LoadCellRepository {
  final LoadCellService _service;
  LoadCellRepository(this._service);

  Future<List<LoadCellReading>> getHistoricalData({
    required String imei,
    required DateTime from,
    required DateTime to,
  }) =>
      _service.getHistoricalData(imei: imei, from: from, to: to);

  Future<List<LoadCellReading>> getLiveData(String imei) => _service.getLiveData(imei);
}