import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/localization/localization_service.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/live_location_session.dart';
import '../../data/services/live_location_service.dart';
import '../pages/live_location_viewer_page.dart';

class LiveLocationBubble extends StatefulWidget {
  final Message message;
  final String chatId;
  final String currentUserId;
  final LiveLocationService liveLocationService;

  const LiveLocationBubble({
    super.key,
    required this.message,
    required this.chatId,
    required this.currentUserId,
    required this.liveLocationService,
  });

  @override
  State<LiveLocationBubble> createState() => _LiveLocationBubbleState();
}

class _LiveLocationBubbleState extends State<LiveLocationBubble> {
  StreamSubscription<LiveLocationSession?>? _sessionSubscription;
  LiveLocationSession? _session;
  Timer? _tickerTimer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _subscribeToSession();
    _startTicker();
  }

  void _subscribeToSession() {
    final sessionId = widget.message.liveLocationSessionId;
    if (sessionId == null || sessionId.isEmpty) return;

    _sessionSubscription = widget.liveLocationService
        .watchSession(widget.chatId, sessionId)
        .listen((session) {
      if (mounted) {
        setState(() {
          _session = session;
          if (session != null) {
            _secondsLeft = session.remainingSeconds;
          }
        });
      }
    });
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _openFullMap(double lat, double lng) {
    final sessionId = widget.message.liveLocationSessionId ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => LiveLocationViewerPage(
          chatId: widget.chatId,
          sessionId: sessionId,
          currentUserId: widget.currentUserId,
          initialLatitude: lat,
          initialLongitude: lng,
          liveLocationService: widget.liveLocationService,
        ),
      ),
    );
  }

  String _formatRemainingDuration(int seconds) {
    if (seconds <= 0) {
      return LocalizationService.translate('sharing_ended');
    }
    final minutes = seconds ~/ 60;
    if (minutes > 0) {
      return '$minutes ${LocalizationService.translate('minutes_remaining')}';
    }
    return '$seconds soniya qoldi';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lat = _session?.latitude ?? widget.message.latitude ?? 41.3113;
    final lng = _session?.longitude ?? widget.message.longitude ?? 69.2797;
    final isActive = _session != null ? _session!.isActive : (_secondsLeft > 0);
    final isSender = widget.message.senderId == widget.currentUserId;

    return GestureDetector(
      onTap: () => _openFullMap(lat, lng),
      child: Container(
        width: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? const Color(0xFF10B981).withOpacity(0.5)
                : (isDark ? Colors.white10 : Colors.black12),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Map preview
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              child: SizedBox(
                height: 125,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(lat, lng),
                        initialZoom: 14.5,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.none,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          maxZoom: 19,
                          userAgentPackageName: 'com.portfolio.chat_app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(lat, lng),
                              width: 38,
                              height: 38,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive
                                      ? const Color(0xFF10B981)
                                      : Colors.grey.shade600,
                                  border: Border.all(
                                      color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Tap to enlarge hint
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.fullscreen_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 2),
                            Text(
                              LocalizationService.translate('open_map'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Info and Countdown Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive
                            ? LocalizationService.translate('live_location')
                            : LocalizationService.translate('sharing_ended'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      if (isActive && isSender)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final sid = widget.message.liveLocationSessionId;
                            if (sid != null) {
                              widget.liveLocationService
                                  .stopLiveLocation(widget.chatId, sid);
                            }
                          },
                          child: Text(
                            LocalizationService.translate('stop_sharing'),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isActive
                        ? _formatRemainingDuration(_secondsLeft)
                        : LocalizationService.translate('sharing_ended'),
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive
                          ? const Color(0xFF10B981)
                          : (isDark ? Colors.white38 : Colors.black38),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
