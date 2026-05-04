import 'package:flutter/material.dart';

class RemoteButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double? width;
  final BorderRadius? borderRadius;

  const RemoteButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.size = 52,
    this.width,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFF1E1E3A);
    final br = borderRadius ?? BorderRadius.circular(size / 2);

    return Material(
      color: bg,
      borderRadius: br,
      child: InkWell(
        onTap: onPressed,
        borderRadius: br,
        splashColor: Colors.white24,
        highlightColor: Colors.white12,
        child: Container(
          width: width ?? size,
          height: size,
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
