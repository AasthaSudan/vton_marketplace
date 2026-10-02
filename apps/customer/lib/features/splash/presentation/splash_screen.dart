import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:clothsy_core/core/theme/app_colors.dart';
import 'package:clothsy_core/core/theme/app_typography.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    _timer = Timer(const Duration(milliseconds: 1400), _proceed);
  }

  Future<void> _proceed() async {
    // A tap and the timer can both fire: only navigate once.
    if (!mounted || _navigated) return;
    _navigated = true;
    _timer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCompleted = prefs.getBool('has_completed_onboarding') ?? false;

      if (!mounted) return;
      if (hasCompleted) {
        context.go('/');
      } else {
        context.go('/onboarding');
      }
    } catch (_) {
      if (mounted) context.go('/onboarding');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      onTap: _proceed,
      child: Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sparkle Emblem
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary.withOpacity(0.06),
                          border: Border.all(
                            color: colors.primary.withOpacity(0.12),
                            width: 1.2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome,
                            size: 34,
                            color: colors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Brand Wordmark
                      Text(
                        'CLOTHSY',
                        style: AppTypography.display(
                          color: colors.primary,
                          weight: FontWeight.w800,
                        ).copyWith(fontSize: 34, letterSpacing: 8.0),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'AI VIRTUAL FITTING STUDIO',
                        style: AppTypography.label(
                          color: colors.textSecondary,
                          weight: FontWeight.w600,
                        ).copyWith(letterSpacing: 3.5, fontSize: 11),
                      ),
                      const SizedBox(height: 36),

                      // Minimal progress line
                      SizedBox(
                        width: 48,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _controller.value,
                            minHeight: 2.5,
                            backgroundColor: colors.primary.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
