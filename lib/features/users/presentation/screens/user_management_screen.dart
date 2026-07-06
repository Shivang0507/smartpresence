import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/enums/organization_type.dart';
import '../../../../core/enums/user_role.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../../auth/data/app_user.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/user_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({
    super.key,
    required this.title,
    this.roles,
    this.repository,
  });

  final String title;
  final List<UserRole>? roles;
  final UserRepository? repository;

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late final UserRepository _repository = widget.repository ?? UserRepository();
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthBloc>().state.user;

    // Resolve dynamic title
    String resolvedTitle = widget.title;
    if (currentUser != null) {
      final category = currentUser.organizationType.category;
      if (widget.roles != null && widget.roles!.contains(UserRole.teacherManager)) {
        resolvedTitle = 'Manage ${category.teacherManagerPlural}';
      } else if (widget.roles != null && widget.roles!.contains(UserRole.receptionist)) {
        resolvedTitle = 'Manage ${category.receptionistLabel}s';
      } else if (widget.roles != null && widget.roles!.contains(UserRole.member)) {
        resolvedTitle = 'Manage ${category.memberPlural}';
      } else if (widget.title == 'Manage Users') {
        resolvedTitle = 'Manage ${category.memberPlural}';
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(resolvedTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: currentUser == null
            ? null
            : () {
                final roleQuery = widget.roles != null && widget.roles!.isNotEmpty
                    ? '?role=${widget.roles!.first.value}'
                    : '';
                context.push('${AppRouter.createUser}$roleQuery');
              },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: currentUser == null
            ? const Center(child: Text('No active user profile found.'))
            : StreamBuilder<List<AppUser>>(
                stream: _repository.watchUsers(
                  organizationId: currentUser.organizationId,
                  roles: widget.roles,
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _MessageState(
                      icon: Icons.error_outline_rounded,
                      message: 'Failed to load users.',
                      detail: snapshot.error.toString(),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = _filterUsers(snapshot.data ?? const <AppUser>[]);
                  if (users.isEmpty) {
                    return ListView(
                      padding: EdgeInsets.all(20.w),
                      children: [
                        _SearchField(
                          controller: _searchController,
                          onChanged: _updateSearchQuery,
                        ),
                        SizedBox(height: 28.h),
                        _MessageState(
                          icon: Icons.people_outline_rounded,
                          message: _searchQuery.isEmpty
                              ? 'No users found.'
                              : 'No users match your search.',
                          detail: _searchQuery.isEmpty
                              ? 'Add the first ${resolvedTitle.toLowerCase()} profile for this organization.'
                              : 'Try a different name, email, phone, or role.',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.all(20.w),
                    itemCount: users.length + 1,
                    separatorBuilder: (_, index) => SizedBox(
                      height: index == 0 ? 18.h : 12.h,
                    ),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _SearchField(
                          controller: _searchController,
                          onChanged: _updateSearchQuery,
                        );
                      }
                      final user = users[index - 1];
                      return PremiumCard(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 420;
                            final actions = [
                              IconButton(
                                tooltip: 'Edit',
                                onPressed: () => _openEditor(
                                  context,
                                  currentUser.organizationId,
                                  user,
                                ),
                                icon: const Icon(Icons.edit_rounded),
                              ),
                              IconButton(
                                tooltip: 'Deactivate',
                                onPressed: user.id == currentUser.id
                                    ? null
                                    : () => _deactivateUser(
                                          context,
                                          currentUser.organizationId,
                                          user,
                                        ),
                                icon: const Icon(Icons.person_off_outlined),
                              ),
                            ];

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _UserSummary(user: user),
                                  SizedBox(height: 8.h),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: actions,
                                  ),
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: _UserSummary(user: user)),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: actions,
                                ),
                              ],
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  List<AppUser> _filterUsers(List<AppUser> users) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return users;
    }
    return users.where((user) {
      return user.name.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query) ||
          (user.phone ?? '').toLowerCase().contains(query) ||
          user.role.label.toLowerCase().contains(query) ||
          user.role.value.toLowerCase().contains(query);
    }).toList();
  }

  void _updateSearchQuery(String value) {
    setState(() => _searchQuery = value);
  }

  Future<void> _deactivateUser(
    BuildContext context,
    String organizationId,
    AppUser user,
  ) async {
    try {
      await _repository.deactivateUser(
        organizationId: organizationId,
        id: user.id,
      );
      if (context.mounted) {
        _showMessage(context, '${user.name} deactivated.');
      }
    } catch (error) {
      if (context.mounted) {
        _showMessage(context, 'Failed to deactivate user: $error');
      }
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    String organizationId, [
    AppUser? user,
  ]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return _UserEditor(
          organizationId: organizationId,
          user: user,
          roles: widget.roles ?? UserRole.values,
          repository: _repository,
        );
      },
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _UserEditor extends StatefulWidget {
  const _UserEditor({
    required this.organizationId,
    this.user,
    required this.roles,
    required this.repository,
  });

  final String organizationId;
  final AppUser? user;
  final List<UserRole> roles;
  final UserRepository repository;

  @override
  State<_UserEditor> createState() => _UserEditorState();
}

class _UserEditorState extends State<_UserEditor> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  final _formKey = GlobalKey<FormState>();
  late UserRole _role;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user?.name);
    _emailController = TextEditingController(text: widget.user?.email);
    _phoneController = TextEditingController(text: widget.user?.phone);
    _role = widget.user?.role ?? widget.roles.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 8.h,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20.h,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.user == null ? 'Add User' : 'Edit User',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16.h),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
              validator: _required,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (value) =>
                  value == null || !value.contains('@') ? 'Enter a valid email' : null,
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            if (widget.roles.length > 1) ...[
              SizedBox(height: 12.h),
              DropdownButtonFormField<UserRole>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: widget.roles
                    .map((role) => DropdownMenuItem(value: role, child: Text(role.label)))
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _role = value ?? _role),
              ),
            ],
            SizedBox(height: 18.h),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      await widget.repository.saveUser(
        organizationId: widget.organizationId,
        user: AppUser(
          id: widget.user?.id ?? '',
          organizationId: widget.organizationId,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _role,
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User saved successfully.')),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save user: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        labelText: 'Search Users',
        prefixIcon: Icon(Icons.search_rounded),
      ),
    );
  }
}

class _UserSummary extends StatelessWidget {
  const _UserSummary({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthBloc>().state.user;
    final secondaryTextColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64);

    return Row(
      children: [
        CircleAvatar(
          backgroundImage: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
              ? CachedNetworkImageProvider(user.profileImageUrl!)
              : null,
          child: user.profileImageUrl != null && user.profileImageUrl!.isNotEmpty
              ? null
              : Text(_initialsFor(user.name)),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: 2.h),
              Text(
                currentUser != null
                    ? currentUser.organizationType.category.roleLabel(user.role)
                    : user.role.label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              SizedBox(height: 2.h),
              Text(
                user.email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                overflow: TextOverflow.ellipsis,
              ),
              if (user.phone != null && user.phone!.isNotEmpty)
                Text(
                  user.phone!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _initialsFor(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.detail,
  });

  final IconData icon;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62);

    return Center(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36.w, color: Theme.of(context).colorScheme.primary),
            SizedBox(height: 12.h),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              SizedBox(height: 6.h),
              Text(
                detail!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mutedColor),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
