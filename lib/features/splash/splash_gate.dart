import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/tokens.dart';
import '../../data/providers.dart';

/// Launch screen, drawn above the app while it really initialises (the Firebase
/// session is restored underneath). Sequence:
///  1. Logo builds up from the bottom with a spring settle and a soft light sweep.
///  2. "Foodz" fades in 150ms later.
///  3. When the intro is done AND the session is known, a circular reveal opens
///     from the centre into the first real screen.
/// Cold start budget: 760ms intro + 340ms reveal. No fake waiting: if the
/// session is slow to restore, the logo simply stays until it is ready.
/// Colours and the 160dp logo match the native splash, so there is no jump.
class SplashGate extends ConsumerStatefulWidget {
  const SplashGate({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends ConsumerState<SplashGate> with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
  late final AnimationController _exit =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 340));

  bool _introDone = false;
  bool _exiting = false;
  bool _gone = false;
  bool _reducedHandled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_intro.forward().whenComplete(() {
      _introDone = true;
      _tryExit();
    }));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_reducedHandled && Motion.reduced(context)) {
      _reducedHandled = true;
      _intro.value = 1;
      _introDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryExit());
    }
  }

  void _tryExit() {
    if (_exiting || !_introDone || !mounted) return;
    if (ref.read(authStateProvider).isLoading) return;
    _exiting = true;
    if (_reducedHandled) {
      setState(() => _gone = true);
      return;
    }
    unawaited(_exit.forward().whenComplete(() {
      if (mounted) setState(() => _gone = true);
    }));
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, __) => _tryExit());
    final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    final palette = dark ? FoodzPalette.dark : FoodzPalette.light;

    // The app is always the first child so its state survives the overlay going away.
    return Stack(
      children: [
        widget.child,
        if (!_gone)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _exit]),
              builder: (context, _) => _overlay(palette),
            ),
          ),
      ],
    );
  }

  Widget _overlay(FoodzPalette p) {
    final t = _intro.value;
    final reveal = Motion.decelerate.transform(const Interval(0, 0.6).transform(t));
    final scale = 0.9 + 0.1 * Curves.easeOutBack.transform(const Interval(0, 0.7).transform(t));
    final sweep = Curves.easeInOut.transform(const Interval(0.4, 0.9).transform(t));
    final word = Curves.easeOut.transform(const Interval(0.35, 0.7).transform(t));
    final out = Motion.decelerate.transform(_exit.value);

    final logo = Image.asset(
      'assets/brand/logo.png',
      width: 160,
      height: 160,
      filterQuality: FilterQuality.medium,
    );

    final lit = ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment(-2 + 4 * sweep, -1),
        end: Alignment(-1 + 4 * sweep, 1),
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      ).createShader(rect),
      child: logo,
    );

    final content = Material(
      color: p.bg,
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (reveal * 1.4).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale * (1 + 0.06 * out),
                child: ClipRect(clipper: _BottomUpClipper(reveal), child: lit),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, 118),
              child: Opacity(
                opacity: word,
                child: Transform.translate(
                  offset: Offset(0, 8 * (1 - word)),
                  child: Text(
                    'Foodz',
                    style: GoogleFonts.cairo(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.84,
                      color: p.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ClipPath(clipper: _HoleClipper(out), child: content);
  }
}

class _BottomUpClipper extends CustomClipper<Rect> {
  const _BottomUpClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, size.height * (1 - progress), size.width, size.height);

  @override
  bool shouldReclip(_BottomUpClipper old) => old.progress != progress;
}

/// Everything except a growing circle: the circle shows the app underneath.
class _HoleClipper extends CustomClipper<Path> {
  const _HoleClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height) / 2;
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: maxRadius * progress));
  }

  @override
  bool shouldReclip(_HoleClipper old) => old.progress != progress;
}
