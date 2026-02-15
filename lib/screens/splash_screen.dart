import 'package:flutter/material.dart';
import 'dart:async';

import 'package:yugo/screens/home_screen.dart';
import 'package:yugo/services/native_service.dart';
import 'package:yugo/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await NativeService.startMonitoring();
      await NativeService.startMacroScheduler();
    } catch (_) {}

    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/icon_dark.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.shield_rounded,
                      size: 36,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Yugo',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Preparando la app...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


