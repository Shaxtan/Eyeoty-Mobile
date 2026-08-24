import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/working_hour_record.dart';
import '../../models/track_point.dart';
import '../../repositories/reports_repository.dart';
import '../../widgets/loading_view.dart';

String _fmtTime(String? v) {
  if (v == null) return '\u2014';
  final d = DateTime.tryParse(v.replaceFirst(' ', 'T'));
  if (d == null) return v;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

String _fmtDuration(dynamic v) {
  if (v == null) return '\u2014';
  if (v is String && v.contains(':')) return v;
  final mins = int.tryParse('$v') ?? 0;
  final h = mins ~/ 60;
  final m = mins % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

/// Ported from HourlyReportPage.jsx's SessionModal + SessionMap.
/// Mobile adaptation: pushed as a full screen (Navigator.push) instead
/// of a centered overlay dialog, since the left-panel-stats +
/// right-panel-map layout doesn't fit mobile width - stats stack above
/// the map instead. Playback is STEP-based via Timer.periodic (500ms
/// per point, matching the original's own setTimeout(step, STEP_MS)
/// exactly) rather than the smooth interpolated animation built for the
/// standalone Track Play screen - this mirrors SessionMap's actual
/// behavior, which is genuinely a different (simpler, discrete) engine
/// from TrackPlayPage's.
class SessionDetailScreen extends StatefulWidget {
  final WorkingHourRecord record;
  const SessionDetailScreen({super.key, required this.record});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  final _mapController = MapController();
  int _activeIdx = 0;
  bool _playing = false;
  bool _loadingRoute = false;
  List<TrackPoint> _route = [];
  int _stepIdx = 0;
  Timer? _timer;

  WorkingHourSession get _session => widget.record.sessions[_activeIdx];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRoute());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    if (widget.record.sessions.isEmpty) return;
    _timer?.cancel();
    setState(() {
      _loadingRoute = true;
      _route = [];
      _stepIdx = 0;
      _playing = false;
    });
    try {
      final pts = await context.read<ReportsRepository>().getTrackPlayHistory(
            imei: widget.record.imei,
            startTime: _session.startTime ?? '',
            endTime: _session.endTime ?? '',
          );
      if (!mounted) return;
      setState(() {
        _route = pts;
        _loadingRoute = false;
      });
      final withLoc = pts.where((p) => p.lat != null && p.lng != null).toList();
      if (withLoc.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.fitCamera(
            CameraFit.coordinates(
              coordinates: withLoc.map((p) => LatLng(p.lat!, p.lng!)).toList(),
              padding: const EdgeInsets.all(40),
            ),
          );
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRoute = false);
    }
  }

  void _selectSession(int i) {
    setState(() => _activeIdx = i);
    _loadRoute();
  }

  void _togglePlay() {
    final withLoc = _route.where((p) => p.lat != null && p.lng != null).toList();
    if (withLoc.isEmpty) return;
    if (_playing) {
      _timer?.cancel();
      setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_stepIdx >= withLoc.length - 1) {
        _timer?.cancel();
        setState(() => _playing = false);
        return;
      }
      setState(() => _stepIdx++);
      final p = withLoc[_stepIdx];
      _mapController.move(LatLng(p.lat!, p.lng!), _mapController.camera.zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final withLoc = _route.where((p) => p.lat != null && p.lng != null).toList();
    final polyline = withLoc.map((p) => LatLng(p.lat!, p.lng!)).toList();
    final markerPos = withLoc.isNotEmpty ? withLoc[_stepIdx.clamp(0, withLoc.length - 1)] : null;
    final progress = withLoc.length > 1 ? ((_stepIdx / (withLoc.length - 1)) * 100).round() : 0;

    final stats = <List<String>>[
      ['Start', _fmtTime(_session.startTime)],
      ['End', _fmtTime(_session.endTime)],
      ['Duration', _fmtDuration(_session.duration)],
      ['Distance', '${_session.distance} km'],
      ['GPS Dist', '${_session.gpsDistance} km'],
      ['Avg Speed', '${_session.avgSpeed} km/h'],
      ['Status', _session.status ?? '\u2014'],
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(r.vehNum ?? r.imei, style: const TextStyle(fontSize: 15)),
        actions: [
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Sessions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: withLoc.isEmpty ? null : _togglePlay,
                      icon: Icon(_playing ? Icons.pause : Icons.play_arrow, size: 14),
                      label: Text(_playing ? 'Pause' : 'Play', style: const TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _playing ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(r.sessions.length, (i) {
                    final active = _activeIdx == i;
                    return ChoiceChip(
                      label: Text('Session ${i + 1}', style: const TextStyle(fontSize: 11)),
                      selected: active,
                      onSelected: (_) => _selectSession(i),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                ...stats.map((kv) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(kv[0], style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                          Text(kv[1], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )),
                if (_session.startLocation != null) ...[
                  const SizedBox(height: 4),
                  Text('Start: ${_session.startLocation}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
                if (_session.endLocation != null) ...[
                  const SizedBox(height: 2),
                  Text('End: ${_session.endLocation}', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(initialCenter: LatLng(22.5, 75.6), initialZoom: 6),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.eyeoty.mobile',
                    ),
                    if (polyline.length > 1)
                      PolylineLayer(polylines: [
                        Polyline(points: polyline, color: const Color(0xFF2563EB), strokeWidth: 3),
                      ]),
                    if (markerPos != null)
                      MarkerLayer(markers: [
                        Marker(
                          point: LatLng(markerPos.lat!, markerPos.lng!),
                          width: 16,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                            ),
                          ),
                        ),
                      ]),
                  ],
                ),
                if (_loadingRoute)
                  Container(
                    color: Colors.white.withValues(alpha: 0.6),
                    alignment: Alignment.center,
                    child: const LoadingView(),
                  ),
                if (polyline.isNotEmpty)
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Progress', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                              Text('$progress%', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(value: progress / 100, minHeight: 5, backgroundColor: Colors.grey.shade200),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}