import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationStatusWidget extends StatelessWidget {
  const LocationStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationStatusResult>(
      future: _checkLocationStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final result = snapshot.data!;

        if (result.serviceEnabled && result.permissionGranted) {
          return const SizedBox.shrink();
        }

        String message;
        IconData icon;
        Color bgColor;

        if (!result.serviceEnabled) {
          message = 'Location services are off';
          icon = Icons.location_off;
          bgColor = const Color(0xFFE5A53C);
        } else if (result.permissionDenied) {
          message = 'Location access denied — tap to enable';
          icon = Icons.location_disabled;
          bgColor = const Color(0xFFE5A53C);
        } else if (result.permissionPermanentlyDenied) {
          message = 'Location permanently denied — open settings';
          icon = Icons.location_off;
          bgColor = const Color(0xFFCF6679);
        } else {
          message = 'Location unavailable';
          icon = Icons.location_off;
          bgColor = Colors.white30;
        }

        return GestureDetector(
          onTap: () {
            if (!result.serviceEnabled) {
              openAppSettings();
            } else if (result.permissionDenied && !result.permissionPermanentlyDenied) {
              Permission.location.request();
            } else if (result.permissionPermanentlyDenied) {
              openAppSettings();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: bgColor.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: bgColor == const Color(0xFFCF6679) ? Colors.white70 : bgColor),
                const SizedBox(width: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: bgColor == const Color(0xFFCF6679) ? Colors.white70 : bgColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<LocationStatusResult> _checkLocationStatus() async {
    final serviceEnabled = await Permission.location.serviceStatus;
    final permStatus = await Permission.location.status;
    return LocationStatusResult(
      serviceEnabled: serviceEnabled.isEnabled,
      permissionGranted: permStatus.isGranted,
      permissionDenied: permStatus.isDenied,
      permissionPermanentlyDenied: permStatus.isPermanentlyDenied,
    );
  }
}

class LocationStatusResult {
  final bool serviceEnabled;
  final bool permissionGranted;
  final bool permissionDenied;
  final bool permissionPermanentlyDenied;

  const LocationStatusResult({
    required this.serviceEnabled,
    required this.permissionGranted,
    required this.permissionDenied,
    required this.permissionPermanentlyDenied,
  });
}