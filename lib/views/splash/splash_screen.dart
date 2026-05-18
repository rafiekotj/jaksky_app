import 'package:flutter/material.dart';
import 'package:jaksky_app/views/home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _windController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animation controller untuk logo
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Setup animation controller untuk garis angin
    _windController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    // Scale animation: logo akan membesar dari 0.5x menjadi 1x
    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Opacity animation: logo fade in
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    // Start animation
    _controller.forward();

    // Navigate ke HomeScreen setelah 3 detik
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _windController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Logo
              Image.asset('assets/logo/JakSky.png', width: 160, height: 160),
              // Garis angin yang bergerak
              AnimatedBuilder(
                animation: _windController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: WindLinePainter(_windController.value),
                    size: const Size(160, 160),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WindLinePainter extends CustomPainter {
  final double animationValue;

  WindLinePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6FA3D1)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    // Posisi awan (kira-kira di tengah kanan)
    final cloudCenterX = size.width * 0.6;
    final cloudCenterY = size.height * 0.35;

    // Membuat 3 garis angin dengan animasi translasi
    for (int i = 0; i < 3; i++) {
      final offset = (animationValue + i * 0.3) % 1.0;
      final startX = cloudCenterX + 30 + (offset * 50);
      final startY = cloudCenterY - 8 + (i * 12).toDouble();

      // Opacity effect saat garis keluar
      final opacity = (1.0 - offset).clamp(0.3, 1.0);

      final lineLength = 20 + (offset * 15);

      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + lineLength, startY),
        paint
          ..color = const Color(0xFF6FA3D1).withAlpha((opacity * 255).toInt()),
      );
    }
  }

  @override
  bool shouldRepaint(WindLinePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
