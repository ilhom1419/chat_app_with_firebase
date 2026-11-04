import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/design_system/app_colors.dart';
import '../../../../core/localization/localization_service.dart';
import '../pages/fullscreen_map_viewer_page.dart';

class InteractiveMapPickerDialog extends StatefulWidget {
  final Function(double lat, double lng, String address) onLocationSelected;

  const InteractiveMapPickerDialog({
    super.key,
    required this.onLocationSelected,
  });

  @override
  State<InteractiveMapPickerDialog> createState() =>
      _InteractiveMapPickerDialogState();
}

class _InteractiveMapPickerDialogState
    extends State<InteractiveMapPickerDialog> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _selectedLatLng = const LatLng(41.3113, 69.2797); // Tashkent default
  String _address = 'Amir Temur maydoni, Toshkent';
  double? _currentAccuracy;
  bool _isLoadingLocation = false;
  bool _isSearchingAddress = false;
  bool _isMapReady = false;
  List<dynamic> _searchResults = [];
  Timer? _geocodeDebounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation(moveMap: true);
  }

  @override
  void dispose() {
    _geocodeDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _safeMoveMap(LatLng latLng, double zoom) {
    if (_isMapReady) {
      try {
        _mapController.move(latLng, zoom);
      } catch (e) {
        debugPrint("Map move error: $e");
      }
    }
  }

  Future<void> _fetchUserLocation({bool moveMap = true}) async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);

    try {
      // 1. Check if location services are enabled on device
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Qurilmada geolokatsiya (GPS) o\'chirilgan. Iltimos, yoqing.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // 2. Check & request permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied && mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocalizationService.translate('location_permission_denied')),
              backgroundColor: Colors.redAccent,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever && mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Lokatsiya ruxsati rad etilgan. Qurilma sozlamalaridan ruxsat bering.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // 3. Fast initial lock: check last known position
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        final lastLatLng = LatLng(lastKnown.latitude, lastKnown.longitude);
        setState(() {
          _selectedLatLng = lastLatLng;
          _currentAccuracy = lastKnown.accuracy;
        });
        if (moveMap) _safeMoveMap(lastLatLng, 16.0);
        _reverseGeocode(lastLatLng.latitude, lastLatLng.longitude);
      }

      // 4. Request current accurate position with timeout
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // Fallback to medium accuracy if high precision takes too long
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        } catch (_) {}
      }

      if (position != null && mounted) {
        final curLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLatLng = curLatLng;
          _currentAccuracy = position!.accuracy;
          _isLoadingLocation = false;
        });
        if (moveMap) _safeMoveMap(curLatLng, 16.5);
        _reverseGeocode(curLatLng.latitude, curLatLng.longitude);
      } else {
        if (mounted) setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      debugPrint("Location error: $e");
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _debounceGeocode(LatLng point) {
    _geocodeDebounceTimer?.cancel();
    _geocodeDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      _reverseGeocode(point.latitude, point.longitude);
    });
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final lang = LocalizationService.langNotifier.value;
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1';
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(
          'User-Agent', 'ChatAppUzbekistan/1.0 (info@chatapp.uz)');
      request.headers.set('Accept-Language',
          lang == 'uz' ? 'uz,en' : (lang == 'ru' ? 'ru,en' : 'en'));
      final response =
          await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content) as Map<String, dynamic>;

        String cleanAddress = '';
        if (json.containsKey('address')) {
          final addr = json['address'] as Map<String, dynamic>;
          final parts = <String>[];
          final road = addr['road'] ??
              addr['pedestrian'] ??
              addr['street'] ??
              addr['residential'];
          final house = addr['house_number'];
          final suburb = addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['quarter'] ??
              addr['district'];
          final city = addr['city'] ??
              addr['town'] ??
              addr['village'] ??
              addr['county'];

          if (road != null) {
            parts.add(house != null ? '$road, $house' : '$road');
          }
          if (suburb != null && !parts.contains(suburb)) {
            parts.add('$suburb');
          }
          if (city != null && !parts.contains(city)) {
            parts.add('$city');
          }

          if (parts.isNotEmpty) {
            cleanAddress = parts.join(', ');
          }
        }

        final displayName = cleanAddress.isNotEmpty
            ? cleanAddress
            : (json['display_name'] as String? ?? '');

        if (displayName.isNotEmpty && mounted) {
          setState(() {
            _address = displayName;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint("Reverse geocode error: $e");
    }

    if (mounted) {
      setState(() {
        _address =
            'Koordinata: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      });
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) return;
    setState(() {
      _isSearchingAddress = true;
      _searchResults = [];
    });

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final lang = LocalizationService.langNotifier.value;
      final url =
          'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&limit=5&addressdetails=1';
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set(
          'User-Agent', 'ChatAppUzbekistan/1.0 (info@chatapp.uz)');
      request.headers.set('Accept-Language',
          lang == 'uz' ? 'uz,en' : (lang == 'ru' ? 'ru,en' : 'en'));
      final response =
          await request.close().timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        final json = jsonDecode(content) as List<dynamic>;
        if (mounted) {
          setState(() {
            _searchResults = json;
            _isSearchingAddress = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Address search error: $e");
    }

    if (mounted) {
      setState(() => _isSearchingAddress = false);
    }
  }

  void _selectSearchResult(dynamic result) {
    final lat = double.tryParse(result['lat'] as String? ?? '');
    final lon = double.tryParse(result['lon'] as String? ?? '');
    if (lat == null || lon == null) return;

    final newPoint = LatLng(lat, lon);
    setState(() {
      _selectedLatLng = newPoint;
      _address = result['display_name'] as String? ?? _address;
      _searchResults = [];
      _searchController.clear();
    });

    _safeMoveMap(newPoint, 16.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Joylashuvni tanlash',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            tooltip: LocalizationService.translate('my_current_location'),
            icon: _isLoadingLocation
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                  ),
            onPressed: () => _fetchUserLocation(moveMap: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Fullscreen Interactive Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLatLng,
              initialZoom: 15.0,
              onMapReady: () {
                _isMapReady = true;
                _safeMoveMap(_selectedLatLng, 15.0);
              },
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _selectedLatLng = position.center;
                  });
                  _debounceGeocode(position.center);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.portfolio.chat_app',
                maxZoom: 19,
              ),
            ],
          ),

          // 2. Fixed Center Pin with sleek pulse effect
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.35),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Colors.redAccent,
                      size: 46,
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Search Bar at Top
          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: LocalizationService.translate('search_address_or_place'),
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.primary,
                      ),
                      suffixIcon: _isSearchingAddress
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                          : (_searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded,
                                      size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                )
                              : null),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                    ),
                    onSubmitted: _searchAddress,
                    textInputAction: TextInputAction.search,
                  ),
                ),

                // Search Results Dropdown List
                if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: isDark ? Colors.white10 : Colors.black12,
                      ),
                      itemBuilder: (ctx, idx) {
                        final res = _searchResults[idx];
                        final name = res['display_name'] as String? ?? '';
                        return ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.place_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          onTap: () => _selectSearchResult(res),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 4. Map Zoom Floating Buttons (Right Side)
          Positioned(
            right: 14,
            bottom: 230,
            child: Column(
              children: [
                _buildMapFloatingButton(
                  icon: Icons.add_rounded,
                  tooltip: LocalizationService.translate('zoom_in'),
                  isDark: isDark,
                  onTap: () {
                    final zoom = _mapController.camera.zoom + 1;
                    _safeMoveMap(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingButton(
                  icon: Icons.remove_rounded,
                  tooltip: LocalizationService.translate('zoom_out'),
                  isDark: isDark,
                  onTap: () {
                    final zoom = _mapController.camera.zoom - 1;
                    _safeMoveMap(_mapController.camera.center, zoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapFloatingButton(
                  icon: Icons.gps_fixed_rounded,
                  tooltip: LocalizationService.translate('my_location_tooltip'),
                  isDark: isDark,
                  iconColor: AppColors.primary,
                  onTap: () => _fetchUserLocation(moveMap: true),
                ),
              ],
            ),
          ),

          // 5. Bottom Card: Selected Address & Send Button
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle line
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_pin,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tanlangan manzil',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _address,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_currentAccuracy != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '~${_currentAccuracy!.toInt()}m',
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Primary Action Button: Send Location
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        widget.onLocationSelected(
                          _selectedLatLng.latitude,
                          _selectedLatLng.longitude,
                          _address,
                        );
                        Navigator.of(context).pop();
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.send_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Ushbu lokatsiyani jo\'natish',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapFloatingButton({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          size: 20,
          color: iconColor ?? (isDark ? Colors.white : Colors.black87),
        ),
        tooltip: tooltip,
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// Fullscreen viewer for shared location messages (delegates to FullscreenMapViewerPage)
class LocationViewerDialog extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? address;

  const LocationViewerDialog({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  @override
  Widget build(BuildContext context) {
    return FullscreenMapViewerPage(
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }
}

