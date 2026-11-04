import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/live_location_session.dart';
import '../../data/services/live_location_service.dart';

class LiveLocationViewerPage extends StatefulWidget {
  final String chatId;
  final String sessionId;
  final String currentUserId;
  final double initialLatitude;
  final double initialLongitude;
  final LiveLocationService liveLocationService;

  const LiveLocationViewerPage({
    super.key,
    required this.chatId,
    required this.sessionId,
    required this.currentUserId,
    required this.initialLatitude,
    required this.initialLongitude,
    required this.liveLocationService,
  });

  @override
  State<LiveLocationViewerPage> createState() => _LiveLocationViewerPageState();
}

class _LiveLocationViewerPageState extends State<LiveLocationViewerPage> {
  final MapController _mapController = MapController();
  StreamSubscription<LiveLocationSession?>? _sessionSubscription;

  LiveLocationSession? _session;
  Timer? _countdownTimer;
  int _secondsLeft = 0;
  bool _isStopping = false;
  bool _isUserPanning = false;

  @override
  void initState() {
    super.initState();
    _subscribeToSession();
    _startCountdown();
  }

  void _subscribeToSession() {
    _sessionSubscription = widget.liveLocationService
        .watchSession(widget.chatId, widget.sessionId)
        .listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
          if (session != null) {
            _secondsLeft = session.remainingSeconds;
          }
        });

        // If user hasn't manually panned away, smoothly adjust map center
        if (session != null && session.isActive && !_isUserPanning) {
          try {
            _mapController.move(
              LatLng(session.latitude, session.longitude),
              _mapController.camera.zoom,
            );
          } catch (_) {}
        }
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleStopSharing() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        title: Text(
          LocalizationService.translate('stop_sharing'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          LocalizationService.translate('stop_sharing_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(LocalizationService.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(LocalizationService.translate('stop_sharing')),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isStopping = true);
    await widget.liveLocationService
        .stopLiveLocation(widget.chatId, widget.sessionId);
    if (mounted) {
      setState(() => _isStopping = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.translate('sharing_ended')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) {
      return LocalizationService.translate('sharing_ended');
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final mStr = minutes.toString().padLeft(2, '0');
    final sStr = seconds.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lat = _session?.latitude ?? widget.initialLatitude;
    final lng = _session?.longitude ?? widget.initialLongitude;
    final isActive = _session != null ? _session!.isActive : (_secondsLeft > 0);
    final isSender = _session != null
        ? _session!.senderId == widget.currentUserId
        : false;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isActive) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  isActive
                      ? LocalizationService.translate('live_location_active')
                      : LocalizationService.translate('sharing_ended'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            if (isActive)
              Text(
                '${LocalizationService.translate('remaining_time')}: ${_formatCountdown(_secondsLeft)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF10B981),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 15.0,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) {
                  _isUserPanning = true;
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                maxZoom: 19,
                userAgentPackageName: 'com.portfolio.chat_app',
              ),
              // Accuracy radius circle if available
              if (_session?.accuracy != null && isActive)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(lat, lng),
                      radius: (_session!.accuracy!).clamp(10, 80).toDouble(),
                      useRadiusInMeter: true,
                      color: AppColors.primary.withOpacity(0.15),
                      borderColor: AppColors.primary.withOpacity(0.4),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              // Marker with live beacon or ended indicator
              MarkerLayer(
                markers: [
                  Marker(
                    point: LatLng(lat, lng),
                    width: 56,
                    height: 56,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isActive)
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF10B981).withOpacity(0.25),
                              ),
                            ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? const Color(0xFF10B981)
                                  : Colors.grey.shade600,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.navigation_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Recentering FAB
          Positioned(
            right: 16,
            bottom: isSender && isActive ? 96 : 24,
            child: FloatingActionButton.small(
              heroTag: 'recenter_live_map',
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              foregroundColor: AppColors.primary,
              onPressed: () {
                _isUserPanning = false;
                try {
                  _mapController.move(LatLng(lat, lng), 16.0);
                } catch (_) {}
              },
              child: const Icon(Icons.my_location_rounded),
            ),
          ),

          // 3. Sender Stop Sharing Bottom Banner
          if (isSender && isActive)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                child: ElevatedButton.icon(
                  onPressed: _isStopping ? null : _handleStopSharing,
                  icon: _isStopping
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.stop_circle_outlined, size: 22),
                  label: Text(
                    LocalizationService.translate('stop_sharing'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
