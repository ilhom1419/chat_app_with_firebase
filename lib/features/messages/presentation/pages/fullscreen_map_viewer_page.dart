import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';

/// Fullscreen interactive map viewer for shared location messages.
/// Centers on the exact message coordinates, supports pinch-to-zoom, pan,
/// recentering, coordinate copying, and returns safely to the chat session.
class FullscreenMapViewerPage extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime? messageTime;

  const FullscreenMapViewerPage({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.messageTime,
  });

  @override
  State<FullscreenMapViewerPage> createState() => _FullscreenMapViewerPageState();
}

class _FullscreenMapViewerPageState extends State<FullscreenMapViewerPage> {
  late final MapController _mapController;
  bool _isMapReady = false;

  bool get _isValidCoordinates =>
      !widget.latitude.isNaN &&
      !widget.longitude.isNaN &&
      widget.latitude >= -90.0 &&
      widget.latitude <= 90.0 &&
      widget.longitude >= -180.0 &&
      widget.longitude <= 180.0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterOnLocation() {
    if (!_isMapReady || !_isValidCoordinates) return;
    try {
      _mapController.move(LatLng(widget.latitude, widget.longitude), 16.0);
    } catch (e) {
      debugPrint('Error recentering map: $e');
    }
  }

  void _zoomIn() {
    if (!_isMapReady) return;
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(
        _mapController.camera.center,
        (currentZoom + 1).clamp(3.0, 18.5),
      );
    } catch (_) {}
  }

  void _zoomOut() {
    if (!_isMapReady) return;
    try {
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(
        _mapController.camera.center,
        (currentZoom - 1).clamp(3.0, 18.5),
      );
    } catch (_) {}
  }

  void _copyCoordinatesToClipboard() {
    final coordStr =
        '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: coordStr));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          LocalizationService.translate('coordinates_copied'),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetPoint = LatLng(widget.latitude, widget.longitude);

    if (!_isValidCoordinates) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        appBar: AppBar(
          title: Text(
            LocalizationService.translate('location_title'),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_rounded,
                    size: 56, color: Colors.orangeAccent),
                const SizedBox(height: 16),
                Text(
                  LocalizationService.translate('invalid_coordinates'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(LocalizationService.translate('back_btn')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.address != null && widget.address!.isNotEmpty
              ? widget.address!
              : LocalizationService.translate('location_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: LocalizationService.translate('copy_coordinates_tooltip'),
            icon: Icon(
              Icons.copy_rounded,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 20,
            ),
            onPressed: _copyCoordinatesToClipboard,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive Flutter Map with OpenStreetMap tiles
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: targetPoint,
              initialZoom: 16.0,
              minZoom: 3.0,
              maxZoom: 18.5,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapReady: () {
                if (mounted) {
                  setState(() => _isMapReady = true);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.portfolio.chat_app',
                maxZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: targetPoint,
                    width: 50,
                    height: 50,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 2. Right-side Floating Zoom & Recenter Controls
          Positioned(
            right: 16,
            bottom: 150,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFloatingButton(
                  icon: Icons.add_rounded,
                  tooltip: LocalizationService.translate('zoom_in'),
                  onTap: _zoomIn,
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _buildFloatingButton(
                  icon: Icons.remove_rounded,
                  tooltip: LocalizationService.translate('zoom_out'),
                  onTap: _zoomOut,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildFloatingButton(
                  icon: Icons.my_location_rounded,
                  tooltip: LocalizationService.translate('my_location_tooltip'),
                  onTap: _recenterOnLocation,
                  isDark: isDark,
                  iconColor: AppColors.primary,
                ),
              ],
            ),
          ),

          // 3. Bottom Address & Coordinate Card
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.redAccent.withOpacity(0.12),
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.address != null &&
                                        widget.address!.isNotEmpty
                                    ? widget.address!
                                    : LocalizationService.translate(
                                        'selected_location'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.latitude.toStringAsFixed(6)}, ${widget.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.copy_rounded,
                            size: 18,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                          tooltip: LocalizationService.translate(
                              'copy_coordinates_tooltip'),
                          onPressed: _copyCoordinatesToClipboard,
                        ),
                      ],
                    ),
                    if (widget.messageTime != null) ...[
                      const Divider(height: 16, thickness: 0.6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat('dd MMM yyyy, HH:mm')
                                .format(widget.messageTime!),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white38 : Colors.black45,
                            ),
                          ),
                          Text(
                            'OpenStreetMap',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white24 : Colors.black26,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required bool isDark,
    Color? iconColor,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ),
    );
  }
}
