import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../auth/axon_logo.dart';

class AxonScaffold extends StatelessWidget {
  const AxonScaffold({
    super.key,
    required this.child,
    this.actions,
    this.maxWidth = 1100,
    this.centerContent = false,
  });

  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final bool centerContent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AxonLogo(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: actions,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _PageBackground(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl + kToolbarHeight,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: centerContent
                      ? Align(alignment: Alignment.topCenter, child: child)
                      : child,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageBackground extends StatelessWidget {
  const _PageBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.background, AppColors.surfaceAlt],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        const Positioned(
          top: -120,
          right: -50,
          child: _GlowCircle(size: 240, color: AppColors.accent),
        ),
        const Positioned(
          bottom: -160,
          left: -70,
          child: _GlowCircle(size: 300, color: AppColors.primary),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.18),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 60,
            spreadRadius: 12,
          ),
        ],
      ),
    );
  }
}
