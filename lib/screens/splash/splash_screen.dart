import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<StatefulWidget> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  bool _showSplash = true;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    debugPrint('[SPLASH] Flutter splash screen initState');

    // HIde system Ui for true fullScreen splash
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _fadeController = AnimationController(
        vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
    );

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      debugPrint('[SPLASH] Flutter out splash screen');
      // Restore system UI
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      _fadeController.forward().then((_) {
        if (mounted) setState(() => _showSplash = false);
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSplash) return widget.child;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final splashImage = isDark
        ? 'assets/image/original/splash/dark.png'
        : 'assets/image/original/splash/light.png';

    debugPrint('[SPLASH] showing splash: $splashImage (isDark=$isDark)');
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        FadeTransition(
          opacity: ReverseAnimation(_fadeAnimation),
          child: Container(
            color: Colors.black,
            child: Image.asset(
              splashImage,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      ],
    );
  }
}