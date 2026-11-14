import 'package:flutter/material.dart';

/// A section of a screen's entrance: it fades up over [from]..[to] of the
/// one controller the screen owns, so the steps can not drift apart.
class Rise extends StatelessWidget {
  const Rise({
    super.key,
    required this.animation,
    required this.from,
    this.to = 1,
    this.distance = 18,
    required this.child,
  });

  final Animation<double> animation;
  final double from;
  final double to;
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(from, to, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: AnimatedBuilder(
        animation: curved,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, distance * (1 - curved.value)),
          child: child,
        ),
        child: child,
      ),
    );
  }
}
