import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Standard page: safe area, title row, centred column with a maximum width.
class PageList extends StatelessWidget {
  const PageList({
    super.key,
    required this.title,
    required this.children,
    this.action,
    this.bottomSpace = Space.s24,
  });

  final String title;
  final List<Widget> children;
  final Widget? action;
  final double bottomSpace;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(Space.s24, Space.s24, Space.s24, bottomSpace),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: Layout.maxContent),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(title, style: text.headlineMedium)),
                      if (action != null) action!,
                    ],
                  ),
                  const SizedBox(height: Space.s16),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section label above a group of cards.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.s4, Space.s24, Space.s4, Space.s8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.palette.textMuted),
      ),
    );
  }
}

/// Placeholder rows shown while a list loads.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 3, this.height = 96});
  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++) ...[
          _Block(height: height),
          const SizedBox(height: Space.s12),
        ],
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: context.palette.surfaceTonal,
          borderRadius: BorderRadius.circular(Radii.xl),
        ),
      );
}
