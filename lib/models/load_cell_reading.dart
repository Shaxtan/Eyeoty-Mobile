/// Ported 1:1 from loadcell.service.js's normaliseRows(): each raw row
/// may carry either an `analog[]` array (index 0-3 = V1-V4) or direct
/// V1-V4 fields - both handled defensively, matching the original.
class LoadCellReading {
  final String time; // "yyyy-MM-dd HH:mm:ss" - same format the original normalises to
  final num v1;
  final num v2;
  final num v3;
  final num v4;
  final num average;
  final num loadPercent;

  LoadCellReading({
    required this.time,
    this.v1 = 0,
    this.v2 = 0,
    this.v3 = 0,
    this.v4 = 0,
    this.average = 0,
    this.loadPercent = 0,
  });

  DateTime? get parsedTime => DateTime.tryParse(time.replaceFirst(' ', 'T'));

  static num _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    return num.tryParse('$v') ?? 0;
  }

  factory LoadCellReading.fromJson(Map<String, dynamic> json) {
    final analog = json['analog'] as List<dynamic>?;
    num pick(int idx, String directKey) {
      if (analog != null && analog.length > idx) return _num(analog[idx]);
      return _num(json[directKey]);
    }

    final rawTs = json['deviceTime'] ?? json['time'];
    final parsed = rawTs != null ? DateTime.tryParse('$rawTs'.replaceFirst(' ', 'T')) : null;
    final d = parsed ?? DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final time = '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';

    return LoadCellReading(
      time: time,
      v1: pick(0, 'V1'),
      v2: pick(1, 'V2'),
      v3: pick(2, 'V3'),
      v4: pick(3, 'V4'),
      average: _num(json['average'] ?? json['Average']),
      loadPercent: _num(json['loadPercent'] ?? json['LoadPercent']),
    );
  }
}