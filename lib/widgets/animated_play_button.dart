import 'package:flutter/material.dart';
import 'package:lyrix/theme/app_theme.dart';

class AnimatedPlayButton extends StatefulWidget {
  final double size;
  final bool isPlaying; // <--- Tambahkan properti ini
  final VoidCallback onPressed; // <--- Tambahkan properti ini

  const AnimatedPlayButton({
    super.key,
    this.size = 64,
    required this.isPlaying, // <--- Jadikan ini required
    required this.onPressed, // <--- Jadikan ini required
  });

  @override
  State<AnimatedPlayButton> createState() => _AnimatedPlayButtonState();
}

class _AnimatedPlayButtonState extends State<AnimatedPlayButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  // Hapus _isPlaying internal karena akan dikontrol dari luar
  // bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Set status awal controller berdasarkan isPlaying dari widget
    if (widget.isPlaying) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedPlayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller progress setiap kali isPlaying dari parent berubah
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Hapus _togglePlayPause internal karena akan menggunakan onPressed dari parent
  // void _togglePlayPause() {
  //   setState(() {
  //     _isPlaying = !_isPlaying;
  //     if (_isPlaying) {
  //       _controller.forward();
  //     } else {
  //       _controller.reverse();
  //     }
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed, // <--- Gunakan onPressed dari widget
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
        child: AnimatedIcon(
          icon: AnimatedIcons.play_pause,
          progress: _controller,
          size: widget.size * 0.5,
          color: Colors.white,
        ),
      ),
    );
  }
}
