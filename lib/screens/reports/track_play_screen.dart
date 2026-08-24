import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/imei_option.dart';
import '../../models/track_point.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/reports_repository.dart';
import '../../widgets/imei_select_field.dart';
import '../../widgets/loading_view.dart';

const _indiaCenter = LatLng(22.5589, 75.6089);
const _statusTypes = ['MOTION', 'STOP', 'IDLE'];

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _lerpAngle(double a, double b, double t) {
  final diff = ((b - a + 540) % 360) - 180;
  return a + diff * t;
}

// Ported exactly from TrackPlayPage.jsx's easeInOut (standard
// easeInOutQuad formula) rather than substituting Curves.easeInOut, for
// precise fidelity to the original's motion feel.
double _easeInOut(double t) => t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;

// Great-circle bearing, ported 1:1 from calcBearing()'s manual fallback
// formula (the JS version prefers L.GeometryUtil.bearing when available,
// falling back to this same math - using the math directly here since
// there's no Leaflet dependency to check for).
double _calcBearing(double fromLat, double fromLng, double toLat, double toLng) {
  final phi1 = fromLat * pi / 180;
  final phi2 = toLat * pi / 180;
  final deltaLambda = (toLng - fromLng) * pi / 180;
  final y = sin(deltaLambda) * cos(phi2);
  final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

DateTime? _parseTs(String? s) {
  if (s == null) return null;
  return DateTime.tryParse(s.replaceFirst(' ', 'T'));
}

String _fmtTs(String? s) {
  final d = _parseTs(s);
  if (d == null) return s ?? '\u2014';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}-${two(d.month)}-${d.year} ${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

Color _statusFg(String s) => s == 'MOTION'
    ? const Color(0xFF047857)
    : s == 'STOP'
        ? const Color(0xFFB91C1C)
        : const Color(0xFFB45309);

/// Ported from TrackPlayPage.jsx. Mobile adaptation: the desktop's
/// collapsible 300px left control panel (overlaying the map) is
/// replaced with a compact filter bar above the map and a playback
/// control strip below it - map stays dominant, same principle used
/// throughout this app's other map screens. Directional arrow
/// decorators on the route (leaflet-polylinedecorator) are NOT ported -
/// flutter_map has no built-in equivalent and it's a cosmetic detail,
/// not core functionality. The animated marker uses a rotating arrow
/// icon instead of a fetched truck PNG, matching every other marker
/// style already used in this app. Map-style switching is NOT ported
/// (utils/mapTiles.js source wasn't shared) - single OSM tile layer.
class TrackPlayScreen extends StatefulWidget {
  const TrackPlayScreen({super.key});

  @override
  State<TrackPlayScreen> createState() => _TrackPlayScreenState();
}

class _TrackPlayScreenState extends State<TrackPlayScreen> with SingleTickerProviderStateMixin {
  final _mapController = MapController();

  List<ImeiOption> _imeiList = [];
  bool _imeiLoading = false;
  ImeiOption? _selectedVeh;

  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String? _quick;

  List<TrackPoint> _vehicleData = [];
  bool _showHistory = false;
  bool _loading = false;
  String? _error;

  List<String> _statusFilter = List.of(_statusTypes);
  double _speed = 1;
  bool _follow = true;
  bool _isPlaying = false;
  bool _isPaused = false;
  bool _historyOpen = false;
  int? _highlightIdx;
  TrackPoint? _playInfo;

  double? _markerLat;
  double? _markerLng;
  double _markerBearing = 0;
  int _currentIdx = 0;
  AnimationController? _segmentController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadImeis());
  }

  @override
  void dispose() {
    _segmentController?.dispose();
    super.dispose();
  }

  Future<void> _loadImeis() async {
    setState(() => _imeiLoading = true);
    final accountId = context.read<AuthProvider>().user?.accountId ?? '1';
    try {
      final list = await context.read<ReportsRepository>().getImeiDropdown(accountId);
      setState(() {
        _imeiList = list;
        _imeiLoading = false;
      });
    } catch (_) {
      setState(() => _imeiLoading = false);
    }
  }

  void _applyQuick(String key) {
    final now = DateTime.now();
    setState(() {
      _quick = key;
      if (key == 'Today') {
        _from = DateTime(now.year, now.month, now.day);
        _to = DateTime(now.year, now.month, now.day, 23, 59, 59);
      } else if (key == 'Yesterday') {
        final y = now.subtract(const Duration(days: 1));
        _from = DateTime(y.year, y.month, y.day);
        _to = DateTime(y.year, y.month, y.day, 23, 59, 59);
      } else {
        _from = now.subtract(const Duration(days: 7));
        _to = now;
      }
    });
  }

  Future<void> _pickDateTime(bool isFrom) async {
    final base = isFrom ? _from : _to;
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
    if (time == null) return;
    setState(() {
      _quick = null;
      final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (isFrom) {
        _from = combined;
      } else {
        _to = combined;
      }
    });
  }

  List<TrackPoint> get _filteredData {
    return _vehicleData.where((r) {
      final ts = _parseTs(r.ts);
      final dateOk = ts == null || (!ts.isBefore(_from) && !ts.isAfter(_to));
      return dateOk && _statusFilter.contains(r.status);
    }).toList();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_selectedVeh == null) {
      setState(() => _error = 'Please select a vehicle.');
      return;
    }
    if (_from.isAfter(_to)) {
      setState(() => _error = 'From date cannot be after To date.');
      return;
    }
    setState(() {
      _loading = true;
      _showHistory = false;
      _vehicleData = [];
      _statusFilter = List.of(_statusTypes);
    });
    _stopAnimation();
    try {
      final points = await context.read<ReportsRepository>().getTrackPlayHistory(
            imei: _selectedVeh!.imei,
            startTime: _from.toUtc().toIso8601String(),
            endTime: _to.toUtc().toIso8601String(),
          );
      if (points.isEmpty) {
        setState(() {
          _error = 'No track data found for the selected period.';
          _loading = false;
        });
        return;
      }
      final sorted = [...points]..sort((a, b) => (_parseTs(a.ts) ?? DateTime(1970)).compareTo(_parseTs(b.ts) ?? DateTime(1970)));
      setState(() {
        _vehicleData = sorted;
        _showHistory = true;
        _loading = false;
      });
      final withLoc = sorted.where((p) => p.lat != null && p.lng != null).toList();
      if (withLoc.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.coordinates(
            coordinates: withLoc.map((p) => LatLng(p.lat!, p.lng!)).toList(),
            padding: const EdgeInsets.all(50),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load track data.';
        _loading = false;
      });
    }
  }

  void _toggleStatus(String type) {
    setState(() {
      _highlightIdx = null;
      final next = List<String>.of(_statusFilter);
      if (next.contains(type)) {
        next.remove(type);
      } else {
        next.add(type);
      }
      if (next.isEmpty) {
        _error = 'At least one status must stay active.';
        return;
      }
      _error = null;
      _statusFilter = next;
    });
  }

  void _startAnimation() {
    if (_vehicleData.length < 2) return;
    setState(() {
      _isPlaying = true;
      _isPaused = false;
    });
    final startIdx = (_currentIdx > 0 && _currentIdx < _vehicleData.length - 1) ? _currentIdx : 0;
    _currentIdx = startIdx;
    final p = _vehicleData[startIdx];
    if (p.lat != null && p.lng != null) {
      setState(() {
        _markerLat = p.lat;
        _markerLng = p.lng;
      });
      if (_follow) {
        final targetZoom = max(_mapController.camera.zoom, 15.0);
        _mapController.move(LatLng(p.lat!, p.lng!), targetZoom);
      }
    }
    _animateSegment(startIdx);
  }

  void _animateSegment(int idx) {
    if (idx >= _vehicleData.length - 1) {
      _stopAnimation();
      return;
    }
    final from = _vehicleData[idx];
    final to = _vehicleData[idx + 1];
    if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) {
      _currentIdx = idx + 1;
      _animateSegment(_currentIdx);
      return;
    }

    final fromBearing = idx > 0 && _vehicleData[idx - 1].lat != null
        ? _calcBearing(_vehicleData[idx - 1].lat!, _vehicleData[idx - 1].lng!, from.lat!, from.lng!)
        : 0.0;
    final toBearing = _calcBearing(from.lat!, from.lng!, to.lat!, to.lng!);

    final durationMs = (600 / _speed).clamp(50, 5000).round();
    _segmentController?.dispose();
    _segmentController = AnimationController(duration: Duration(milliseconds: durationMs), vsync: this);
    _segmentController!.addListener(() {
      final t = _segmentController!.value;
      final e = _easeInOut(t);
      final lat = _lerp(from.lat!, to.lat!, e);
      final lng = _lerp(from.lng!, to.lng!, e);
      final bearing = _lerpAngle(fromBearing, toBearing, e);
      setState(() {
        _markerLat = lat;
        _markerLng = lng;
        _markerBearing = bearing;
        _highlightIdx = idx;
        _playInfo = to;
      });
      if (_follow) {
        _mapController.move(LatLng(lat, lng), _mapController.camera.zoom);
      }
    });
    _segmentController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _currentIdx = idx + 1;
        if (_currentIdx >= _vehicleData.length - 1) {
          setState(() => _highlightIdx = _vehicleData.length - 1);
          _stopAnimation();
        } else {
          _animateSegment(_currentIdx);
        }
      }
    });
    _segmentController!.forward();
  }

  void _stopAnimation() {
    _segmentController?.stop();
    _segmentController?.dispose();
    _segmentController = null;
    _currentIdx = 0;
    setState(() {
      _isPlaying = false;
      _isPaused = false;
      _highlightIdx = null;
      _playInfo = null;
      _markerLat = null;
      _markerLng = null;
    });
  }

  void _togglePlay() {
    if (_segmentController != null && _segmentController!.isAnimating) {
      _segmentController!.stop();
      setState(() {
        _isPaused = true;
        _isPlaying = false;
      });
    } else if (_isPaused) {
      _startAnimation();
    } else {
      _currentIdx = 0;
      _startAnimation();
    }
  }

  void _handleSpeed(double v) {
    setState(() => _speed = v);
    if (_segmentController != null && _segmentController!.isAnimating) {
      _segmentController!.stop();
    }
  }

  String _fmtShort(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredData;
    final playing = _isPlaying && !_isPaused;
    final progressPct = (_highlightIdx != null && _vehicleData.length > 1) ? ((_highlightIdx! / (_vehicleData.length - 1)) * 100).round() : 0;

    final withLoc = _vehicleData.where((p) => p.lat != null && p.lng != null).toList();
    final polyline = withLoc.map((p) => LatLng(p.lat!, p.lng!)).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Track Play', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ImeiSelectField(
                options: _imeiList,
                value: _selectedVeh?.imei,
                loading: _imeiLoading,
                onChanged: (o) {
                  setState(() {
                    _selectedVeh = o;
                    _showHistory = false;
                    _statusFilter = List.of(_statusTypes);
                  });
                  _stopAnimation();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(true),
                      child: Text('From: ${_fmtShort(_from)}', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDateTime(false),
                      child: Text('To: ${_fmtShort(_to)}', style: const TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...['Today', 'Yesterday', '7 Days'].map((q) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(q, style: const TextStyle(fontSize: 11)),
                          selected: _quick == q,
                          onSelected: (_) => _applyQuick(q),
                        ),
                      )),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _loading || _selectedVeh == null ? null : _submit,
                    icon: _loading
                        ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search, size: 14),
                    label: Text(_loading ? 'Loading\u2026' : 'Get Track', style: const TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFE11D48), fontSize: 11)),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(initialCenter: _indiaCenter, initialZoom: 5),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.eyeoty.mobile',
                  ),
                  if (polyline.length > 1)
                    PolylineLayer(polylines: [
                      Polyline(points: polyline, color: const Color(0xFF2563EB), strokeWidth: 4),
                    ]),
                  MarkerLayer(markers: [
                    if (polyline.isNotEmpty)
                      Marker(
                        point: polyline.first,
                        width: 60,
                        height: 24,
                        child: _badge('START', const Color(0xFF10B981)),
                      ),
                    if (polyline.length > 1)
                      Marker(
                        point: polyline.last,
                        width: 50,
                        height: 24,
                        child: _badge('END', const Color(0xFFEF4444)),
                      ),
                    // Only STOP/IDLE point markers — MOTION points cover
                    // the whole polyline and would hide the route line,
                    // matching the original's own reasoning.
                    if (!(_segmentController?.isAnimating ?? false) && !_isPaused)
                      ...filtered.where((r) => r.status != 'MOTION' && r.lat != null && r.lng != null).map((r) => Marker(
                            point: LatLng(r.lat!, r.lng!),
                            width: 10,
                            height: 10,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _statusFg(r.status),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          )),
                    if (_markerLat != null && _markerLng != null)
                      Marker(
                        point: LatLng(_markerLat!, _markerLng!),
                        width: 34,
                        height: 34,
                        child: Transform.rotate(
                          angle: _markerBearing * pi / 180,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.navigation, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
              if (_loading)
                Container(
                  color: Colors.white.withValues(alpha: 0.6),
                  alignment: Alignment.center,
                  child: const LoadingView(),
                ),
            ],
          ),
        ),
        if (_showHistory && filtered.isNotEmpty)
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: _statusTypes.map((type) {
                    final on = _statusFilter.contains(type);
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(type, style: const TextStyle(fontSize: 10)),
                        selected: on,
                        onSelected: (_) => _toggleStatus(type),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Speed: ${_speed}x', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    Expanded(
                      child: Slider(
                        value: _speed,
                        min: 0.25,
                        max: 4,
                        divisions: 15,
                        onChanged: _handleSpeed,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _vehicleData.length < 2 ? null : _togglePlay,
                        icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 16),
                        label: Text(playing ? 'Pause' : (_isPaused ? 'Resume' : 'Play'), style: const TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(backgroundColor: playing ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: (_segmentController != null || _isPaused) ? _stopAnimation : null,
                        icon: const Icon(Icons.stop, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Stop', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Follow', style: TextStyle(fontSize: 10)),
                      selected: _follow,
                      onSelected: (v) => setState(() => _follow = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(value: progressPct / 100, minHeight: 5, backgroundColor: Colors.grey.shade200),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$progressPct%', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _statCell('Speed', '${_playInfo?.speed ?? _vehicleData.first.speed} km/h'),
                      _statCell('Status', _playInfo?.status ?? _vehicleData.first.status),
                      _statCell('Time', _playInfo?.ts != null ? _fmtTs(_playInfo!.ts) : '\u2014'),
                      _statCell('Lat', _playInfo?.lat?.toStringAsFixed(5) ?? '\u2014'),
                      _statCell('Lng', _playInfo?.lng?.toStringAsFixed(5) ?? '\u2014'),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => setState(() => _historyOpen = !_historyOpen),
                  child: Text('${_historyOpen ? 'Hide' : 'Show'} History (${filtered.length})', style: const TextStyle(fontSize: 11)),
                ),
                if (_historyOpen)
                  Container(
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(8)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final rec = filtered[i];
                        final active = i == _highlightIdx;
                        return ListTile(
                          dense: true,
                          tileColor: active ? const Color(0xFFECFEFF) : null,
                          title: Text('${_fmtTs(rec.ts)} \u2014 ${rec.status} @ ${rec.speed} km/h', style: const TextStyle(fontSize: 11)),
                          onTap: () {
                            setState(() => _highlightIdx = i);
                            if (rec.lat != null && rec.lng != null) {
                              _mapController.move(LatLng(rec.lat!, rec.lng!), 16);
                            }
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
      ]),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }

  Widget _statCell(String label, String value) {
    return Container(
      width: 90,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade100), borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis, maxLines: 1),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}