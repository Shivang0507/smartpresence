import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/theme_cubit.dart';
import '../../../../core/widgets/premium_card.dart';

class ThemeSettingsScreen extends StatelessWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentMode = context.watch<ThemeCubit>().state;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final options = [
      _ThemeOption(
        mode: ThemeMode.system,
        icon: Icons.brightness_auto_rounded,
        title: 'System Default',
        subtitle: 'Follows your device light/dark setting',
      ),
      _ThemeOption(
        mode: ThemeMode.light,
        icon: Icons.light_mode_rounded,
        title: 'Light',
        subtitle: 'Always use the light theme',
      ),
      _ThemeOption(
        mode: ThemeMode.dark,
        icon: Icons.dark_mode_rounded,
        title: 'Dark',
        subtitle: 'Always use the dark theme',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Appearance')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            // ── Preview banner ─────────────────────────────────────────────
            PremiumCard(
              margin: EdgeInsets.only(bottom: 24.h),
              child: Row(
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                    child: Icon(
                      _iconFor(currentMode),
                      color: Colors.white,
                      size: 26.w,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Theme',
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.55),
                          ),
                        ),
                        Text(
                          _labelFor(currentMode),
                          style: tt.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Changes apply instantly',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms),

            Text(
              'SELECT THEME',
              style: tt.labelSmall?.copyWith(
                color: cs.onSurface.withValues(alpha: 0.5),
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8.h),

            // ── Theme options ──────────────────────────────────────────────
            for (int i = 0; i < options.length; i++)
              PremiumCard(
                margin: EdgeInsets.only(bottom: 10.h),
                onTap: () =>
                    context.read<ThemeCubit>().setTheme(options[i].mode),
                child: _ThemeOptionTile(
                  option: options[i],
                  selected: currentMode == options[i].mode,
                  onTap: () =>
                      context.read<ThemeCubit>().setTheme(options[i].mode),
                ),
              ).animate().fadeIn(
                    duration: 350.ms,
                    delay: Duration(milliseconds: i * 60),
                  ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
        _ => Icons.brightness_auto_rounded,
      };

  String _labelFor(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        _ => 'System Default',
      };
}

// ── Custom option tile (avoids deprecated RadioListTile groupValue) ─────────

class _ThemeOptionTile extends StatelessWidget {
  const _ThemeOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.14)
              : cs.onSurface.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(
          option.icon,
          color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5),
          size: 20.w,
        ),
      ),
      title: Text(
        option.title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? cs.primary : cs.onSurface,
        ),
      ),
      subtitle: Text(
        option.subtitle,
        style: TextStyle(
          fontSize: 12.sp,
          color: cs.onSurface.withValues(alpha: 0.55),
        ),
      ),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 22.w,
        height: 22.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? cs.primary : cs.onSurface.withValues(alpha: 0.3),
            width: selected ? 6 : 2,
          ),
          color: cs.surface,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ThemeOption {
  const _ThemeOption({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final ThemeMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
}
