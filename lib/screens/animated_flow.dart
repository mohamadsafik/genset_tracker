import 'package:flutter/material.dart';

class AnimatedFlowLine extends StatefulWidget {
  final double width;
  final double height;
  final bool isActive;
  final Color color;
  final Axis direction;

  const AnimatedFlowLine({
    super.key,
    this.width = 50,
    this.height = 4,
    required this.isActive,
    required this.color,
    this.direction = Axis.horizontal,
  });

  @override
  State<AnimatedFlowLine> createState() => _AnimatedFlowLineState();
}

class _AnimatedFlowLineState extends State<AnimatedFlowLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: widget.color.withOpacity(0.3),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: widget.direction == Axis.horizontal
                  ? Alignment.centerLeft
                  : Alignment.topCenter,
              end: widget.direction == Axis.horizontal
                  ? Alignment.centerRight
                  : Alignment.bottomCenter,
              stops: [
                (_controller.value - 0.2).clamp(0.0, 1.0),
                (_controller.value).clamp(0.0, 1.0),
                (_controller.value + 0.2).clamp(0.0, 1.0),
              ],
              colors: [
                widget.color.withOpacity(0.1),
                widget.color,
                widget.color.withOpacity(0.1),
              ],
            ),
          ),
        );
      },
    );
  }
}
