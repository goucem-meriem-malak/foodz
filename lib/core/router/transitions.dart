import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/tokens.dart';

/// Screen transition: fade plus a 3% rise, decelerating. Off for reduced motion.
CustomTransitionPage<void> fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.screen,
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondary, child) {
      if (Motion.reduced(context)) return child;
      final curved = animation.drive(CurveTween(curve: Motion.decelerate));
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: curved.drive(Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)),
          child: child,
        ),
      );
    },
  );
}
