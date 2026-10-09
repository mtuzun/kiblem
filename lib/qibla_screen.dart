import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'ad_banner.dart';
import 'l10n.dart';
import 'qibla_compass.dart';
import 'qibla_geometry.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});
  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> with WidgetsBindingObserver {
  final _mapController = MapController();
  final _directions = StreamController<QiblahDirection>.broadcast();
  final _alignment = QiblaAlignment();
  StreamSubscription<CompassEvent>? _compassSubscription;
  StreamSubscription<Position>? _locationSubscription;
  Position? _position;
  LatLng? _cityPosition;
  String? _city;
  String? _error;
  double? _heading;
  double? _accuracy;
  bool _mapMode = false;
  bool _noSensor = false;
  bool _loading = true;
  bool _mapReady = false;
  bool _tileError = false;
  LocationPermission? _permission;
  bool _serviceEnabled = true;
  bool _requestInFlight = false;
  bool _active = true;

  LatLng get _point => LatLng(_position!.latitude, _position!.longitude);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCompass();
    _loadLocation();
  }

  Future<void> _startCompass() async {
    if (_compassSubscription != null) return;
    try {
      final supported =
          await FlutterQiblah.androidDeviceSensorSupport() ?? true;
      if (!mounted || !_active) return;
      final events = supported ? FlutterCompass.events : null;
      if (events == null) {
        setState(() {
          _noSensor = true;
          _mapMode = true;
        });
        return;
      }
      _compassSubscription = events.listen(
        (event) {
          if (!mounted) return;
          setState(() {
            _heading = event.heading;
            _accuracy = event.accuracy;
          });
          _publishDirection();
        },
        onError: (Object error) {
          if (mounted) {
            setState(() {
              _noSensor = true;
              _mapMode = true;
            });
          }
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _noSensor = true;
          _mapMode = true;
        });
      }
    }
  }

  void _publishDirection() {
    if (_position == null || _heading == null) return;
    final bearing = qiblaBearing(_point);
    final turn = signedQiblaTurn(_heading!, bearing);
    final reliable = _accuracy == null || _accuracy! <= 30;
    if (_alignment.update(turn, DateTime.now(), reliable: reliable) &&
        !_mapMode) {
      unawaited(HapticFeedback.lightImpact());
    }
    _directions.add(
      QiblahDirection((_heading! - bearing + 360) % 360, _heading!, bearing),
    );
  }

  Future<void> _loadLocation() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!_serviceEnabled) throw StateError('service');
      _permission = await Geolocator.checkPermission();
      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();
      }
      if (_permission == LocationPermission.denied ||
          _permission == LocationPermission.deniedForever) {
        throw StateError('permission');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted || !_active) return;
      _setPosition(position);
      await _locationSubscription?.cancel();
      if (!mounted) return;
      _locationSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            _setPosition,
            onError: (Object error) {
              if (mounted) {
                setState(
                  () => _error = t(
                    'Konum güncellenemedi. Yeniden deneyin.',
                    'Location could not be updated. Please retry.',
                  ),
                );
              }
            },
          );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = !_serviceEnabled
            ? t('Konum servisini açın.', 'Turn on location services.')
            : _permission == LocationPermission.denied ||
                  _permission == LocationPermission.deniedForever
            ? t(
                'Kıble yönü için konum izni gerekiyor.',
                'Location permission is needed to find the Qibla.',
              )
            : t(
                'Konum alınamadı. Açık bir alanda yeniden deneyin.',
                'Location unavailable. Try again in an open area.',
              ),
      );
    } finally {
      _requestInFlight = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setPosition(Position position) {
    if (!mounted) return;
    setState(() {
      _position = position;
      _error = null;
    });
    _publishDirection();
    if (_cityPosition == null ||
        const Distance()(_cityPosition!, _point) > 1000) {
      _cityPosition = _point;
      unawaited(_resolveCity(_point));
    }
  }

  Future<void> _resolveCity(LatLng point) async {
    if (mounted) setState(() => _city = null);
    try {
      final places = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (!mounted || _cityPosition != point || places.isEmpty) return;
      final place = places.first;
      final city =
          [
                place.locality,
                place.subAdministrativeArea,
                place.administrativeArea,
              ]
              .whereType<String>()
              .where((value) => value.trim().isNotEmpty)
              .firstOrNull;
      setState(() => _city = city);
    } catch (_) {
      // Coordinates and bearing remain usable without reverse geocoding.
    }
  }

  Future<void> _retry() async {
    if (!_serviceEnabled) {
      await Geolocator.openLocationSettings();
    } else if (_permission == LocationPermission.deniedForever) {
      await Geolocator.openAppSettings();
    }
    if (mounted) await _loadLocation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _active = true;
      _startCompass();
      _loadLocation();
    } else if (state == AppLifecycleState.paused) {
      _active = false;
      _compassSubscription?.cancel();
      _compassSubscription = null;
      _locationSubscription?.cancel();
      _locationSubscription = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSubscription?.cancel();
    _locationSubscription?.cancel();
    _directions.close();
    _mapController.dispose();
    super.dispose();
  }

  void _calibrationHelp() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('Pusula kalibrasyonu', 'Compass calibration'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  t(
                    'Telefonu metal ve mıknatıslardan uzak tutun. Telefonla havada birkaç kez 8 şekli çizin, ardından yatay tutup kıbleye dönün.',
                    'Keep your phone away from metal and magnets. Move it in a figure eight several times, then hold it flat and turn toward the Qibla.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t(
                    'Doğruluk göstergesi sensörün bildirdiği düzeydir; kesin ölçüm değildir. Harita modu pusula sensöründen bağımsızdır.',
                    'The accuracy indicator is the level reported by the sensor, not an exact measurement. Map mode works independently of the compass.',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(t('Tamam', 'Done')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _locationCard() {
    final point = _point;
    final km =
        const Distance(calculator: Haversine())(point, kaabaLocation) / 1000;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _city ?? t('Bulunduğunuz konum', 'Your location'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              t(
                'Kâbe’ye yaklaşık ${km.toStringAsFixed(0)} km',
                'About ${km.toStringAsFixed(0)} km to the Kaaba',
              ),
            ),
            Text(
              t(
                'Kıble açısı: ${qiblaBearing(point).toStringAsFixed(1)}° (kuzeyden)',
                'Qibla bearing: ${qiblaBearing(point).toStringAsFixed(1)}° from north',
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: Text(t('Konum ayrıntıları', 'Location details')),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(
                    '${t('Enlem', 'Latitude')}: ${point.latitude.abs().toStringAsFixed(5)}° ${point.latitude >= 0 ? t('K', 'N') : t('G', 'S')}\n'
                    '${t('Boylam', 'Longitude')}: ${point.longitude.abs().toStringAsFixed(5)}° ${point.longitude >= 0 ? t('D', 'E') : t('B', 'W')}\n'
                    '${t('Konum doğruluğu', 'Location accuracy')}: ±${_position!.accuracy.toStringAsFixed(0)} m',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _map() => SizedBox(
    height: MediaQuery.sizeOf(context).height < 600 ? 260 : 360,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _point,
              initialZoom: 15,
              onMapReady: () => _mapReady = true,
            ),
            children: [
              TileLayer(
                urlTemplate: const String.fromEnvironment(
                  'MAP_TILE_URL',
                  defaultValue:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                ),
                userAgentPackageName: 'com.metint.kiblem',
                maxNativeZoom: 19,
                errorTileCallback: (tile, error, stackTrace) {
                  if (_tileError) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _tileError = true);
                  });
                },
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: qiblaRoute(_point),
                    color: Colors.green.shade700,
                    strokeWidth: 4,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _point,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 32,
                    ),
                  ),
                  Marker(
                    point: kaabaLocation,
                    width: 44,
                    height: 44,
                    child: const Icon(
                      Icons.mosque,
                      color: Colors.black,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'qibla-recenter',
                  tooltip: t('Konumuma dön', 'My location'),
                  onPressed: () {
                    if (_mapReady) _mapController.move(_point, 15);
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'qibla-route',
                  tooltip: t('Kâbe yönünü göster', 'Show direction to Kaaba'),
                  onPressed: () {
                    if (_mapReady) {
                      _mapController.fitCamera(
                        CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints(qiblaRoute(_point)),
                          padding: const EdgeInsets.all(48),
                        ),
                      );
                    }
                  },
                  child: const Icon(Icons.zoom_out_map),
                ),
              ],
            ),
          ),
          if (_tileError)
            Positioned(
              top: 12,
              left: 8,
              right: 70,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    t(
                      'Harita yüklenemedi. İnternet bağlantınızı kontrol edin.',
                      'Map unavailable. Check your internet connection.',
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ColoredBox(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  '© OpenStreetMap contributors',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: const SafeArea(child: Center(heightFactor: 1, child: AdBanner())),
    appBar: AppBar(
      title: Text(t('Kıble Yönü', 'Qibla Direction')),
      backgroundColor: const Color(0xFF6DAF89),
      actions: [
        IconButton(
          onPressed: _loading ? null : _loadLocation,
          tooltip: t('Konumu yenile', 'Refresh location'),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: _position == null
        ? Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_loading)
                      const CircularProgressIndicator()
                    else ...[
                      const Icon(Icons.location_off, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _error ??
                            t('Konum alınamadı.', 'Location unavailable.'),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _retry,
                        child: Text(
                          t('Yeniden dene / Ayarlar', 'Retry / Settings'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        enabled: !_noSensor,
                        icon: const Icon(Icons.explore),
                        label: Text(t('Pusula', 'Compass')),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(t('Harita', 'Map')),
                      ),
                    ],
                    selected: {_mapMode},
                    onSelectionChanged: (value) => setState(() {
                      _mapMode = value.first;
                      _mapReady = false;
                      _tileError = false;
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) Text(_error!, textAlign: TextAlign.center),
                if (_loading) const LinearProgressIndicator(),
                if (_noSensor)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      t(
                        'Pusula sensörü kullanılamıyor. Kıble yönünü haritada görebilirsiniz.',
                        'Compass unavailable. You can view the Qibla direction on the map.',
                      ),
                    ),
                  ),
                if (_mapMode)
                  _map()
                else
                  QiblaCompass(
                    stream: _directions.stream,
                    initialDirection: _heading == null
                        ? null
                        : QiblahDirection(
                            (_heading! - qiblaBearing(_point) + 360) % 360,
                            _heading!,
                            qiblaBearing(_point),
                          ),
                    reliable: _accuracy == null || _accuracy! <= 30,
                  ),
                const SizedBox(height: 16),
                if (!_mapMode)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        _accuracy != null && _accuracy! > 30
                            ? Icons.warning_amber
                            : Icons.explore_outlined,
                      ),
                      title: Text(t('Pusula doğruluğu', 'Compass accuracy')),
                      subtitle: Text(
                        _accuracy == null
                            ? t(
                                'Sensör doğruluk bilgisi sağlamıyor',
                                'Accuracy information unavailable',
                              )
                            : _accuracy! <= 15
                            ? t('Yüksek', 'High')
                            : _accuracy! <= 30
                            ? t('Orta', 'Medium')
                            : t(
                                'Düşük — kalibrasyon önerilir',
                                'Low — calibration recommended',
                              ),
                      ),
                      onTap: _calibrationHelp,
                    ),
                  ),
                _locationCard(),
                TextButton.icon(
                  onPressed: _calibrationHelp,
                  icon: const Icon(Icons.help_outline),
                  label: Text(t('Kalibrasyon yardımı', 'Calibration help')),
                ),
              ],
            ),
          ),
  );
}
