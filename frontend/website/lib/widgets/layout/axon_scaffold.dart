import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../auth/axon_logo.dart';

class AxonScaffold extends StatelessWidget {
  const AxonScaffold({
    super.key,
    required this.child,
    this.actions,
    this.maxWidth = 1100,
    this.centerContent = false,
    this.scrollable = true,
  });

  final Widget child;
  final List<Widget>? actions;
  final double maxWidth;
  final bool centerContent;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const AxonLogo(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: actions,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.surface, cs.surfaceContainerLow],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: scrollable
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: centerContent
                          ? Align(alignment: Alignment.topCenter, child: child)
                          : child,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
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
      ),
    );
  }
}


