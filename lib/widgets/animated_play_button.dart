import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';

class AnimatedPlayButton extends StatefulWidget {
  final double size;
  final bool isPlaying;
  final VoidCallback onPressed;

  const AnimatedPlayButton({
    super.key,
    this.size = 64,
    required this.isPlaying,
    required this.onPressed,
  });

  @override
  State<AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<AnimatedPlayButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          widget.isPlaying ? Icons.pause : Icons.play_arrow,
          size: widget.size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
