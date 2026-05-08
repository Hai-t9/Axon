import 'package:flutter/material.dart';

class TopNotification {
  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String message, {bool isError = false}) {
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context);
    
    _currentEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: child,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isError ? const Color(0xFFE53935) : const Color(0xFF43A047),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _currentEntry?.remove();
                        _currentEntry = null;
                      },
                      child: const Icon(Icons.close, color: Colors.white70, size: 20),
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_currentEntry!);

    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (_currentEntry != null) {
        _currentEntry?.remove();
        _currentEntry = null;
      }
    });
  }
}
