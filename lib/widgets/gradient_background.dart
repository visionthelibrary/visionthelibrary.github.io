import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.backgroundTop,
            AppColors.backgroundMiddle,
            AppColors.backgroundBottom,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: child,
    );
  }
}
