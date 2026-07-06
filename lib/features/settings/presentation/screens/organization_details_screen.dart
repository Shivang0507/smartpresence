import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/constants/firestore_paths.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class OrganizationDetailsScreen extends StatefulWidget {
  const OrganizationDetailsScreen({super.key});

  @override
  State<OrganizationDetailsScreen> createState() =>
      _OrganizationDetailsScreenState();
}

class _OrganizationDetailsScreenState
    extends State<OrganizationDetailsScreen> {
  final _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _orgData;
  bool _loading = true;
  String? _error;
  bool _editMode = false;
  bool _saving = false;

  // Edit controllers
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _websiteCtrl;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
    _fetchOrg();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchOrg() async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null || user.organizationId.isEmpty) {
      setState(() {
        _error = 'No organization found for your account.';
        _loading = false;
      });
      return;
    }
    try {
      final snap = await _firestore
          .collection(FirestorePaths.organizations)
          .doc(user.organizationId)
          .get();
      if (!snap.exists || snap.data() == null) {
        setState(() {
          _error = 'Organization data not found.';
          _loading = false;
        });
        return;
      }
      final data = snap.data()!;
      _nameCtrl.text = data['name'] as String? ?? '';
      _phoneCtrl.text = data['phone'] as String? ?? '';
      _addressCtrl.text = data['address'] as String? ?? '';
      _emailCtrl.text = data['email'] as String? ?? '';
      _websiteCtrl.text = data['website'] as String? ?? '';
      setState(() {
        _orgData = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load organization: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final user = context.read<AuthBloc>().state.user!;
      await _firestore
          .collection(FirestorePaths.organizations)
          .doc(user.organizationId)
          .update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        _orgData = {
          ..._orgData!,
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'website': _websiteCtrl.text.trim(),
        };
        _editMode = false;
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Organization updated successfully.')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;
    final isAdmin = user?.role == UserRole.admin;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization'),
        actions: [
          if (isAdmin && !_loading && _error == null)
            _editMode
                ? TextButton(
                    onPressed: () => setState(() => _editMode = false),
                    child: const Text('Cancel'),
                  )
                : IconButton(
                    tooltip: 'Edit',
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => setState(() => _editMode = true),
                  ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _ErrorState(message: _error!, onRetry: _fetchOrg)
                : _buildBody(cs, isAdmin),
      ),
    );
  }

  Widget _buildBody(ColorScheme cs, bool isAdmin) {
    final data = _orgData!;
    final orgType = _humanType(data);
    final createdAt = _formatTimestamp(data['createdAt']);
    final orgCode = _buildCode(data['name'] as String? ?? '');

    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.all(20.w),
        children: [
          // ── Brand card ──────────────────────────────────────────────────
          PremiumCard(
            margin: EdgeInsets.only(bottom: 20.h),
            child: Row(
              children: [
                Container(
                  width: 60.w,
                  height: 60.w,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(Icons.apartment_rounded, color: cs.primary, size: 30.w),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['name'] as String? ?? 'Organization',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        orgType,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 13.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: orgCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Organization code copied.')),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 11.w, color: cs.primary),
                              SizedBox(width: 4.w),
                              Text(
                                orgCode,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: cs.primary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms),

          // ── Contact info ────────────────────────────────────────────────
          PremiumCard(
            margin: EdgeInsets.only(bottom: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Contact Information'),
                SizedBox(height: 12.h),
                if (_editMode) ...[
                  _EditField(
                    controller: _nameCtrl,
                    label: 'Organization Name',
                    icon: Icons.business_rounded,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 12.h),
                  _EditField(
                    controller: _phoneCtrl,
                    label: 'Phone Number',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  SizedBox(height: 12.h),
                  _EditField(
                    controller: _emailCtrl,
                    label: 'Email Address',
                    icon: Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: 12.h),
                  _EditField(
                    controller: _websiteCtrl,
                    label: 'Website',
                    icon: Icons.language_rounded,
                    keyboardType: TextInputType.url,
                  ),
                ] else ...[
                  _InfoRow(icon: Icons.phone_rounded, label: 'Phone', value: data['phone'] as String? ?? '—'),
                  _InfoRow(icon: Icons.email_rounded, label: 'Email', value: data['email'] as String? ?? '—'),
                  _InfoRow(icon: Icons.language_rounded, label: 'Website', value: data['website'] as String? ?? '—'),
                ],
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 50.ms),

          // ── Address ─────────────────────────────────────────────────────
          PremiumCard(
            margin: EdgeInsets.only(bottom: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'Address'),
                SizedBox(height: 12.h),
                if (_editMode)
                  _EditField(
                    controller: _addressCtrl,
                    label: 'Full Address',
                    icon: Icons.location_on_rounded,
                    maxLines: 3,
                  )
                else
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    label: 'Address',
                    value: data['address'] as String? ?? '—',
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 100.ms),

          // ── System info ─────────────────────────────────────────────────
          PremiumCard(
            margin: EdgeInsets.only(bottom: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionHeader(title: 'System Information'),
                SizedBox(height: 12.h),
                _InfoRow(icon: Icons.category_rounded, label: 'Organization Type', value: orgType),
                _InfoRow(icon: Icons.verified_user_rounded, label: 'Plan', value: _capitalize(data['plan'] as String? ?? 'Starter')),
                _InfoRow(icon: Icons.access_time_rounded, label: 'Timezone', value: data['timezone'] as String? ?? 'Not set'),
                _InfoRow(icon: Icons.calendar_today_rounded, label: 'Created', value: createdAt),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms, delay: 150.ms),

          // ── Save button (edit mode) ──────────────────────────────────────
          if (_editMode)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveChanges,
                icon: _saving
                    ? SizedBox.square(
                        dimension: 16.w,
                        child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save Changes'),
              ),
            ).animate().fadeIn(duration: 300.ms),
        ],
      ),
    );
  }

  String _humanType(Map<String, dynamic> data) {
    final label = data['type'] as String?;
    final name = data['organizationType'] as String?;
    if (label != null && label.isNotEmpty) return label;
    if (name != null && name.isNotEmpty) return _capitalize(name);
    return 'Organization';
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'Unknown';
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.day} ${_month(d.month)} ${d.year}';
    }
    return ts.toString();
  }

  String _month(int m) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return m >= 1 && m <= 12 ? months[m] : '';
  }

  String _buildCode(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'ORG';
    if (words.length == 1) return words[0].substring(0, words[0].length.clamp(0, 5)).toUpperCase();
    return words.take(4).map((w) => w[0].toUpperCase()).join();
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.w, color: cs.onSurface.withValues(alpha: 0.45)),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: cs.onSurface.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
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
            Icon(Icons.error_outline_rounded,
                size: 48.w, color: AppColors.danger),
            SizedBox(height: 12.h),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
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
