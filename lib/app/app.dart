import 'package:flutter/material.dart';
import 'package:luna_sight/app/config/app_config.dart';
import 'package:luna_sight/app/router/app_router.dart';
import 'package:luna_sight/app/theme/app_theme.dart';
import 'package:luna_sight/core/constants/app_constants.dart';

/// LunaSight root application widget.
///
/// Configures theme modes, declarative routing, and application metadata.
class LunaSightApp extends StatelessWidget {
  final AppConfig config;

  const LunaSightApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appName.isNotEmpty ? config.appName : AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      initialRoute: AppRouter.initialRoute,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}
