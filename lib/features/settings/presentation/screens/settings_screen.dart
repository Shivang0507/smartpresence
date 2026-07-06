import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          children: [
            // ── User header ────────────────────────────────────────────────
            if (user != null)
              PremiumCard(
                margin: EdgeInsets.only(bottom: 20.h),
                onTap: () => context.push(AppRouter.profile),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26.r,
                      backgroundImage:
                          user.profileImageUrl?.isNotEmpty == true
                              ? NetworkImage(user.profileImageUrl!)
                              : null,
                      child: user.profileImageUrl?.isNotEmpty == true
                          ? null
                          : Text(
                              user.name.trim().isEmpty
                                  ? 'U'
                                  : user.name.trim()[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    SizedBox(width: 14.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: tt.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user.email,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurface.withValues(alpha: 0.55),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              user.role.label,
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w600,
                                color: cs.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),

            // ── Main settings tiles ────────────────────────────────────────
            _SettingsTile(
              icon: Icons.apartment_rounded,
              title: 'Organization',
              subtitle: user?.organizationName ?? 'View organization details',
              onTap: () => context.push(AppRouter.settingsOrganization),
            ),
            _SettingsTile(
              icon: Icons.palette_rounded,
              title: 'Appearance',
              subtitle: 'Light, dark, or system theme',
              onTap: () => context.push(AppRouter.settingsTheme),
            ),
            _SettingsTile(
              icon: Icons.security_rounded,
              title: 'Security',
              subtitle: 'QR rotation, face verification, access roles',
              onTap: () => context.push(AppRouter.settingsSecurity),
            ),
            _SettingsTile(
              icon: Icons.info_rounded,
              title: 'About',
              subtitle: 'SmartPresence v1.0.0',
              onTap: () => context.push(AppRouter.settingsAbout),
            ),

            SizedBox(height: 12.h),

            // ── Logout ─────────────────────────────────────────────────────
            PremiumCard(
              onTap: () => _confirmLogout(context),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _IconBox(
                  icon: Icons.logout_rounded,
                  color: cs.error,
                ),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.error,
                  ),
                ),
                subtitle: Text(
                  'End this SmartPresence session',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55),
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final cs = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to end your SmartPresence session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
    }
  }
}

// ── Shared helper widgets ──────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PremiumCard(
      margin: EdgeInsets.only(bottom: 10.h),
      onTap: onTap,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _IconBox(icon: icon, color: cs.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.55),
            fontSize: 12.sp,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: cs.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(icon, color: color, size: 20.w),
    );
  }
}
