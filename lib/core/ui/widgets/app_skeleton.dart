import 'package:flutter/material.dart';

import '../app_tokens.dart';
import '../app_context_ext.dart';

class AppSkeleton extends StatefulWidget {
  final double height;
  final double width;
  final double radius;

  const AppSkeleton({
    super.key,
    required this.height,
    this.width = double.infinity,
    this.radius = AppTokens.rMd,
  });

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final base = cs.surfaceContainerHighest.withOpacity(0.55);
    final hi = cs.surfaceContainerHighest.withOpacity(0.85);

    return AnimatedBuilder(
      animation: _c,
      builder: (ctx, _) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t, -0.3),
              end: Alignment(1 + 2 * t, 0.3),
              colors: [base, hi, base],
            ),
          ),
        );
      },
    );
  }
}
