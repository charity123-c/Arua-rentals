import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class ShimmerBox extends StatefulWidget {
  const ShimmerBox({this.width, this.height, this.borderRadius, super.key});

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.shimmerDuration,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = ColorTween(
      begin: colors.surfaceContainerHighest,
      end: colors.surfaceContainerLow,
    ).animate(_controller);
    return AnimatedBuilder(
      animation: color,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: color.value,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}
