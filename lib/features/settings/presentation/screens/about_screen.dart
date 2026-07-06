import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _version = '1.0.0';
  static const _buildNumber = '1';
  static const _releaseDate = 'July 2025';
  static const _contactEmail = 'support@smartpresence.io';
  static const _website = 'https://smartpresence.io';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(20.w),
          children: [
            // ── Brand hero ─────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  SizedBox(height: 16.h),
                  Container(
                    width: 88.w,
                    height: 88.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22.r),
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(14.w),
                    child: Image.asset(
                      'assets/branding/smartpresence_mark.png',
                      fit: BoxFit.contain,
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                  SizedBox(height: 14.h),
                  Text(
                    'SmartPresence',
                    style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                  ).animate().fadeIn(delay: 100.ms),
                  SizedBox(height: 4.h),
                  Text(
                    'Smart Attendance & Workforce Management',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.55),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _VersionChip(label: 'v$_version'),
                      SizedBox(width: 8.w),
                      _VersionChip(label: 'Build $_buildNumber'),
                      SizedBox(width: 8.w),
                      _VersionChip(label: _releaseDate),
                    ],
                  ).animate().fadeIn(delay: 200.ms),
                  SizedBox(height: 24.h),
                ],
              ),
            ),

            // ── Description ────────────────────────────────────────────────
            PremiumCard(
              margin: EdgeInsets.only(bottom: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(title: 'About SmartPresence', icon: Icons.info_rounded),
                  SizedBox(height: 10.h),
                  Text(
                    'SmartPresence is an enterprise-grade attendance and workforce management '
                    'platform built for schools, colleges, hospitals, factories, corporate offices, '
                    'and training centers. It combines dynamic QR attendance with biometric face '
                    'verification for secure, fraud-resistant tracking.',
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.75),
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 100.ms),

            // ── Developer ──────────────────────────────────────────────────
            PremiumCard(
              margin: EdgeInsets.only(bottom: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CardHeader(title: 'Developer', icon: Icons.code_rounded),
                  SizedBox(height: 10.h),
                  _InfoRow(icon: Icons.business_rounded, text: 'SmartPresence Technologies'),
                  _InfoRow(icon: Icons.email_rounded, text: _contactEmail),
                  _InfoRow(icon: Icons.language_rounded, text: _website),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 150.ms),

            // ── Action buttons ─────────────────────────────────────────────
            PremiumCard(
              margin: EdgeInsets.only(bottom: 14.h),
              child: Column(
                children: [
                  _ActionButton(
                    icon: Icons.email_outlined,
                    label: 'Contact Support',
                    onTap: () => _copyToClipboard(context, _contactEmail, 'Email copied to clipboard'),
                  ),
                  Divider(height: 1.h),
                  _ActionButton(
                    icon: Icons.open_in_browser_rounded,
                    label: 'Visit Website',
                    onTap: () => _copyToClipboard(context, _website, 'Website URL copied to clipboard'),
                  ),
                  Divider(height: 1.h),
                  _ActionButton(
                    icon: Icons.system_update_rounded,
                    label: 'Check for Updates',
                    trailing: _ComingSoonBadge(),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You are on the latest version (v$_version).')),
                      );
                    },
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 200.ms),

            // ── Legal ──────────────────────────────────────────────────────
            PremiumCard(
              margin: EdgeInsets.only(bottom: 14.h),
              child: Column(
                children: [
                  _ActionButton(
                    icon: Icons.privacy_tip_rounded,
                    label: 'Privacy Policy',
                    onTap: () => _showSimpleDialog(
                      context,
                      title: 'Privacy Policy',
                      content:
                          'SmartPresence collects and processes only the data required to '
                          'operate the attendance system. Biometric data is stored securely '
                          'and never shared with third parties without consent.\n\n'
                          'For the full policy visit: $_website/privacy',
                    ),
                  ),
                  Divider(height: 1.h),
                  _ActionButton(
                    icon: Icons.gavel_rounded,
                    label: 'Terms & Conditions',
                    onTap: () => _showSimpleDialog(
                      context,
                      title: 'Terms & Conditions',
                      content:
                          'By using SmartPresence, you agree to use the platform only for '
                          'legitimate attendance tracking purposes. Misuse of biometric data '
                          'or attendance records is strictly prohibited.\n\n'
                          'Full terms available at: $_website/terms',
                    ),
                  ),
                  Divider(height: 1.h),
                  _ActionButton(
                    icon: Icons.book_rounded,
                    label: 'Open Source Licenses',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'SmartPresence',
                      applicationVersion: 'v$_version',
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms, delay: 250.ms),

            // ── Footer ─────────────────────────────────────────────────────
            Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.h),
                child: Column(
                  children: [
                    Text(
                      '© ${DateTime.now().year} SmartPresence Technologies',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'Made with ❤️ for workforce management',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSimpleDialog(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// ── Widgets ────────────────────────────────────────────────────────────────

class _VersionChip extends StatelessWidget {
  const _VersionChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: cs.primary,
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16.w, color: cs.primary),
        SizedBox(width: 8.w),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: cs.primary,
            fontSize: 13.sp,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(icon, size: 15.w, color: cs.onSurface.withValues(alpha: 0.45)),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.sp),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Icon(icon, color: cs.primary, size: 20.w),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: trailing ?? Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.35)),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        'Soon',
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w700,
          color: AppColors.warning,
        ),
      ),
    );
  }
}
