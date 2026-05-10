import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';

class ImageMetadata {
  final double? latitude;
  final double? longitude;
  final String? deviceModel;
  final String? deviceBrand;
  final String? timestamp;

  const ImageMetadata({
    this.latitude,
    this.longitude,
    this.deviceModel,
    this.deviceBrand,
    this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      if (latitude != null) 'gps_latitude': latitude,
      if (longitude != null) 'gps_longitude': longitude,
      if (deviceModel != null) 'device_model': deviceModel,
      if (deviceBrand != null) 'device_brand': deviceBrand,
      'timestamp': timestamp ?? DateTime.now().toIso8601String(),
    };
  }
}

class MetadataService {
  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      ),
    );
  }

  Future<Map<String, String>> getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      final androidInfo = await deviceInfo.androidInfo;
      return {
        'device_model': androidInfo.model,
        'device_brand': androidInfo.brand,
      };
    } catch (_) {
      try {
        final iosInfo = await deviceInfo.iosInfo;
        return {
          'device_model': iosInfo.model,
          'device_brand': iosInfo.systemName,
        };
      } catch (_) {
        return {
          'device_model': 'Unknown',
          'device_brand': 'Unknown',
        };
      }
    }
  }

  Future<ImageMetadata> captureMetadata() async {
    final position = await getCurrentPosition();
    final deviceInfo = await getDeviceInfo();

    return ImageMetadata(
      latitude: position?.latitude,
      longitude: position?.longitude,
      deviceModel: deviceInfo['device_model'],
      deviceBrand: deviceInfo['device_brand'],
      timestamp: DateTime.now().toIso8601String(),
    );
  }
}
