import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

const kaabaLocation = LatLng(21.422487, 39.826206);

double qiblaBearing(LatLng origin) {
  final lat = origin.latitudeInRad;
  final target = kaabaLocation.latitudeInRad;
  final delta = kaabaLocation.longitudeInRad - origin.longitudeInRad;
  return (math.atan2(
                math.sin(delta) * math.cos(target),
                math.cos(lat) * math.sin(target) -
                    math.sin(lat) * math.cos(target) * math.cos(delta),
              ) *
              180 /
              math.pi +
          360) %
      360;
}

double signedQiblaTurn(double heading, double bearing) =>
    (bearing - heading + 540) % 360 - 180;

List<LatLng> qiblaRoute(LatLng origin) {
  const distance = Distance(calculator: Haversine());
  final meters = distance(origin, kaabaLocation);
  final bearing = qiblaBearing(origin);
  return [
    origin,
    for (var i = 1; i < 64; i++)
      distance.offset(origin, meters * i / 64, bearing),
    kaabaLocation,
  ];
}

/// Hysteresis prevents repeated feedback when the compass jitters at alignment.
class QiblaAlignment {
  bool aligned = false;
  DateTime? _lastFeedback;

  bool update(double turn, DateTime now, {bool reliable = true}) {
    if (!reliable || turn.abs() > 6) {
      aligned = false;
      return false;
    }
    if (turn.abs() > 3 || aligned) return false;
    aligned = true;
    if (_lastFeedback != null &&
        now.difference(_lastFeedback!) < const Duration(seconds: 3)) {
      return false;
    }
    _lastFeedback = now;
    return true;
  }
}
