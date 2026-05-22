import 'package:flutter/material.dart';

import '../core/navigation/app_route_observer.dart';
import '../core/theme/app_theme.dart';
import '../features/splash/splash_screen.dart';

class MentalHealthApp extends StatelessWidget {
  const MentalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ЦМЗ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorObservers: [appRouteObserver],
      builder: (context, child) {
        debugPrint(
          'Building MaterialApp shell background=${AppColors.background}',
        );
        return ColoredBox(
          color: AppColors.background,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
