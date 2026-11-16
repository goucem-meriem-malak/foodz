import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// First-load entrance: fade in plus an 8px move up, 40ms between siblings.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.screen);
  late final Animation<double> _curve = CurvedAnimation(parent: _c, curve: Motion.decelerate);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    final delay = Motion.stagger * widget.index;
    if (delay == Duration.zero) {
      unawaited(_c.forward());
    } else {
      _timer = Timer(delay, () {
        if (mounted) unawaited(_c.forward());
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, Motion.enterOffset * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
