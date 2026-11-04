import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../domain/entities/message.dart';
import 'chat_bubble_theme.dart';
import '../pages/fullscreen_map_viewer_page.dart';

/// A modern, compact, elegant location message preview card.
/// Features clean OpenStreetMap view, high-contrast address/title,
/// and trailing timestamp/status integration without bulky outer borders.
class LocationMessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final MessageGroupPosition position;
  final Widget? statusWidget;

  const LocationMessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.position = MessageGroupPosition.single,
    this.statusWidget,
  });

  @override
  Widget build(BuildContext context) {
    final lat = message.latitude;
    final lng = message.longitude;
    if (lat == null || lng == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxBubbleWidth =
        (MediaQuery.of(context).size.width * 0.78).clamp(240.0, 280.0);
    final bubbleRadius = ChatBubbleTheme.getBubbleRadius(isMe, position);
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    // Top border radius for map clipping
    final mapRadius = BorderRadius.only(
      topLeft: bubbleRadius.topLeft,
      topRight: bubbleRadius.topRight,
    );

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (ctx) => FullscreenMapViewerPage(
              latitude: lat,
              longitude: lng,
              address: message.address,
              messageTime: message.timestamp,
            ),
          ),
        );
      },
      borderRadius: bubbleRadius,
      child: Container(
        width: maxBubbleWidth,
        decoration: BoxDecoration(
          borderRadius: bubbleRadius,
          color: isMe
              ? (isDark ? const Color(0xFF4338CA) : AppColors.primary)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          border: isMe
              ? null
              : Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : const Color(0xFFE2E8F0),
                  width: 0.75,
                ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Map preview card
            ClipRRect(
              borderRadius: mapRadius,
              child: SizedBox(
                height: 140,
                child: IgnorePointer(
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
                              width: 36,
                              height: 36,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.redAccent,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.25),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

            // 2. Address & Timestamp Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.place_rounded,
                          size: 15,
                          color: isMe
                              ? Colors.white
                              : (isDark
                                  ? const Color(0xFF818CF8)
                                  : AppColors.primary),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          message.address != null && message.address!.trim().isNotEmpty
                              ? message.address!
                              : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: isMe
                                ? Colors.white
                                : (isDark
                                    ? const Color(0xFFF8FAFC)
                                    : const Color(0xFF0F172A)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: isMe
                              ? Colors.white.withOpacity(0.72)
                              : (isDark
                                  ? Colors.white54
                                  : AppColors.textSecondaryLight),
                        ),
                      ),
                      if (statusWidget != null) ...[
                        const SizedBox(width: 4),
                        statusWidget!,
                      ],
                    ],
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
