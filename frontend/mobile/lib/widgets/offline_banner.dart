import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/offline_queue_service.dart';

class OfflineBanner extends ConsumerWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivity = ref.watch(connectivityProvider);

    return Column(
      children: [
        connectivity.when(
          data: (isOnline) {
            if (isOnline) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              color: const Color(0xFFE5A53C),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: const SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'No internet connection — uploads will be queued',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        Expanded(child: child),
      ],
    );
  }
}