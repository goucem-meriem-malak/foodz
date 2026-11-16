import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shimmer placeholder shaped like the real content. Never a bare spinner.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, required this.height, this.radius = Radii.md});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = p.surfaceTonal;
    final glow = Color.lerp(p.surfaceTonal, p.surface, 0.7)!;
    return Semantics(
      container: true,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: LinearGradient(
                  begin: Alignment(-1.5 + 3 * t, 0),
                  end: Alignment(-0.5 + 3 * t, 0),
                  colors: [base, glow, base],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Skeleton of the home header, used while the profile loads.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Skeleton(height: 112, radius: Radii.xl),
        SizedBox(height: Space.s16),
        Skeleton(height: 20, width: 180),
        SizedBox(height: Space.s12),
        Skeleton(height: 160, radius: Radii.xl),
      ],
    );
  }
}
