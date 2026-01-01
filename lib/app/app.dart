import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import 'routes.dart';
import 'theme.dart';

class YugoApp extends StatelessWidget {
  const YugoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
