import 'package:alraya_app/alrayah.dart';
import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 10), () {
      Navigator.pushReplacementNamed(context, '/');
    });
  }

  @override
  Widget build(BuildContext context) {
    final gradient = ShaderMask(
      shaderCallback: (bounds) => LinearGradient(
        colors: [DesertColors.primaryGoldDark, Colors.red],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(
        '', // placeholder, overridden by DefaultTextStyle
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFD670),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/images/logo.png", height: 200),
            const SizedBox(height: 30),
            AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  'Alrayah App',
                  textStyle: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [DesertColors.primaryGoldDark, Colors.red],
                      ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
                  ),
                  speed: const Duration(milliseconds: 150), // typing speed
                ),
                FadeAnimatedText(
                  'Explore Islamic Libraries and Join Events',
                  textStyle: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        colors: [DesertColors.primaryGoldDark, Colors.red],
                      ).createShader(const Rect.fromLTWH(0, 0, 300, 70)),
                  ),
                  duration: const Duration(seconds: 6), // show for 4 seconds
                ),
              ],
              totalRepeatCount: 1,
              isRepeatingAnimation: false,
              displayFullTextOnTap: true,
              stopPauseOnTap: true,
            ),
          ],
        ),
      ),
    );
  }
}
