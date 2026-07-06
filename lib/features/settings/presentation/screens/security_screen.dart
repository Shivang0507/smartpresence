import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth, EmailAuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _settings;
  bool _loading = true;
  String? _error;
  bool _savingSettings = false;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null || user.organizationId.isEmpty) {
      setState(() {
        _error = 'No organization found.';
        _loading = false;
      });
      return;
    }
    try {
      final snap = await _firestore
          .collection(FirestorePaths.organizations)
          .doc(user.organizationId)
          .collection(FirestorePaths.settings)
          .doc('default')
          .get();
      setState(() {
        _settings = snap.data() ?? {};
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load security settings: $e';
        _loading = false;
      });
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _savingSettings = true);
    try {
      final user = context.read<AuthBloc>().state.user!;
      await _firestore
          .collection(FirestorePaths.organizations)
          .doc(user.organizationId)
          .collection(FirestorePaths.settings)
          .doc('default')
          .set({key: value, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
      setState(() {
        _settings = {..._settings!, key: value};
        _savingSettings = false;
      });
    } catch (e) {
      setState(() => _savingSettings = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final isAdmin = user?.role.name == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _fetchSettings)
                : _buildBody(context, isAdmin, user),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isAdmin, appUser) {
    final cs = Theme.of(context).colorScheme;
    final settings = _settings ?? {};

    final qrEnabled = settings['qrRotationEnabled'] as bool? ?? true;
    final qrInterval = (settings['qrRotationIntervalSeconds'] as int?) ?? 30;
    final faceEnabled = settings['faceVerificationEnabled'] as bool? ?? true;
    final dupProtect = settings['duplicateProtectionEnabled'] as bool? ?? true;
    final attendanceMode = settings['attendanceMode'] as String? ?? 'face_qr_hybrid';

    final fbUser = FirebaseAuth.instance.currentUser;
    final lastSignIn = fbUser?.metadata.lastSignInTime;

    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        // ── Attendance Security ────────────────────────────────────────────
        _SectionLabel(title: 'Attendance Security'),
        SizedBox(height: 8.h),
        PremiumCard(
          margin: EdgeInsets.only(bottom: 14.h),
          child: Column(
            children: [
              _SwitchTile(
                icon: Icons.qr_code_2_rounded,
                title: 'QR Rotation',
                subtitle: 'Rotating QR for anti-spoofing',
                value: qrEnabled,
                enabled: isAdmin && !_savingSettings,
                onChanged: (v) => _updateSetting('qrRotationEnabled', v),
              ),
              Divider(height: 1.h),
              _InfoTile(
                icon: Icons.timer_rounded,
                title: 'QR Rotation Interval',
                trailing: _Badge(
                  label: '${qrInterval}s',
                  color: cs.primary,
                ),
              ),
              Divider(height: 1.h),
              _SwitchTile(
                icon: Icons.face_retouching_natural_rounded,
                title: 'Face Verification',
                subtitle: 'Biometric attendance verification',
                value: faceEnabled,
                enabled: isAdmin && !_savingSettings,
                onChanged: (v) => _updateSetting('faceVerificationEnabled', v),
              ),
              Divider(height: 1.h),
              _SwitchTile(
                icon: Icons.block_rounded,
                title: 'Duplicate Protection',
                subtitle: 'Prevent marking attendance twice',
                value: dupProtect,
                enabled: isAdmin && !_savingSettings,
                onChanged: (v) => _updateSetting('duplicateProtectionEnabled', v),
              ),
              Divider(height: 1.h),
              _InfoTile(
                icon: Icons.settings_input_composite_rounded,
                title: 'Attendance Mode',
                trailing: _Badge(
                  label: _formatMode(attendanceMode),
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms),

        // ── Account Security ───────────────────────────────────────────────
        _SectionLabel(title: 'Account Security'),
        SizedBox(height: 8.h),
        PremiumCard(
          margin: EdgeInsets.only(bottom: 14.h),
          child: Column(
            children: [
              _ActionTile(
                icon: Icons.lock_reset_rounded,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePassword(context),
              ),
              Divider(height: 1.h),
              _ActionTile(
                icon: Icons.mark_email_read_rounded,
                title: 'Send Password Reset Email',
                subtitle: 'Receive a reset link at your email',
                onTap: () => _sendPasswordReset(context),
              ),
              Divider(height: 1.h),
              _InfoTile(
                icon: Icons.access_time_rounded,
                title: 'Last Sign-In',
                trailing: Text(
                  lastSignIn != null
                      ? _formatDateTime(lastSignIn)
                      : 'Unknown',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: cs.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Divider(height: 1.h),
              _InfoTile(
                icon: Icons.devices_rounded,
                title: 'Active Session',
                trailing: _Badge(label: 'This device', color: AppColors.success),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms, delay: 80.ms),

        // ── User Access ────────────────────────────────────────────────────
        _SectionLabel(title: 'User Access & Permissions'),
        SizedBox(height: 8.h),
        PremiumCard(
          margin: EdgeInsets.only(bottom: 14.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoTile(
                icon: Icons.badge_rounded,
                title: 'Assigned Role',
                trailing: _Badge(
                  label: appUser?.role.label ?? 'Unknown',
                  color: cs.primary,
                ),
              ),
              Divider(height: 1.h),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(bottom: 8.h),
                      child: Row(
                        children: [
                          Icon(Icons.checklist_rounded, size: 18.w, color: cs.primary),
                          SizedBox(width: 10.w),
                          Text('Permissions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp)),
                        ],
                      ),
                    ),
                    ..._permissionsFor(appUser?.role.name ?? '').map(
                      (p) => Padding(
                        padding: EdgeInsets.only(bottom: 6.h),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14.w, color: AppColors.success),
                            SizedBox(width: 8.w),
                            Text(p, style: TextStyle(fontSize: 12.sp)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 350.ms, delay: 160.ms),

        if (!isAdmin)
          Padding(
            padding: EdgeInsets.only(bottom: 16.h),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 14.w, color: cs.onSurface.withValues(alpha: 0.4)),
                SizedBox(width: 6.w),
                Expanded(
                  child: Text(
                    'Security settings can only be modified by an administrator.',
                    style: TextStyle(fontSize: 11.sp, color: cs.onSurface.withValues(alpha: 0.45)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showChangePassword(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ChangePasswordSheet(),
    );
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password reset email sent to ${user.email}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _formatMode(String mode) {
    return switch (mode) {
      'face_qr_hybrid' => 'Face + QR',
      'qr_only' => 'QR Only',
      'face_only' => 'Face Only',
      _ => mode,
    };
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  List<String> _permissionsFor(String role) {
    return switch (role) {
      'admin' => [
          'Manage all users & roles',
          'Configure organization settings',
          'Access all reports & analytics',
          'Start & manage attendance sessions',
          'Manage departments, teams & shifts',
        ],
      'receptionist' => [
          'Start attendance sessions',
          'View attendance records',
          'Mark manual attendance',
          'View basic reports',
        ],
      'teacherManager' => [
          'Start attendance sessions',
          'View team/class attendance',
          'Access assigned reports',
        ],
      _ => [
          'Mark own attendance',
          'View personal attendance history',
          'View profile information',
        ],
    };
  }
}

// ── Change Password Bottom Sheet ───────────────────────────────────────────

class _ChangePasswordSheet extends StatefulWidget {
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser == null || fbUser.email == null) throw Exception('Not signed in');
      final cred = EmailAuthProvider.credential(
        email: fbUser.email!,
        password: _currentCtrl.text,
      );
      await fbUser.reauthenticateWithCredential(cred);
      await fbUser.updatePassword(_newCtrl.text);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 8.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24.h,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Change Password',
                style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 20.h),
            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) =>
                  v == null || v.length < 6 ? 'At least 6 characters' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) =>
                  v != _newCtrl.text ? 'Passwords do not match' : null,
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? SizedBox.square(
                        dimension: 16.w,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving...' : 'Update Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared tile widgets ────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 1.0,
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
      secondary: Icon(icon, color: cs.primary, size: 22.w),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.sp, color: cs.onSurface.withValues(alpha: 0.55)),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
      leading: Icon(icon, color: cs.primary, size: 22.w),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: trailing,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
      onTap: onTap,
      leading: Icon(icon, color: cs.primary, size: 22.w),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 11.sp, color: cs.onSurface.withValues(alpha: 0.55)),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.35)),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48.w, color: AppColors.danger),
            SizedBox(height: 12.h),
            Text(message, textAlign: TextAlign.center),
            SizedBox(height: 16.h),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
