import 'package:flutter/material.dart';

import '../../app/theme/tokens.dart';
import '../responsive/breakpoints.dart';

/// Membatasi lebar konten bacaan dan memusatkannya (DESIGN_SYSTEM §8).
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: Breakpoints.contentMaxWidth),
        child: child,
      ),
    );
  }
}

/// ListView dengan padding standar halaman + lebar terbatas.
class ContentListView extends StatelessWidget {
  const ContentListView({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      AppSpacing.xxl,
    ),
    this.controller,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: controller,
      padding: padding,
      children: [
        for (final child in children) ContentWidth(child: child),
      ],
    );
  }
}
