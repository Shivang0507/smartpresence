import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/enums/organization_type.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../data/auth_repository.dart';
import '../bloc/auth_bloc.dart';

class OrganizationRegistrationScreen extends StatefulWidget {
  const OrganizationRegistrationScreen({super.key});

  @override
  State<OrganizationRegistrationScreen> createState() => _OrganizationRegistrationScreenState();
}

class _OrganizationRegistrationScreenState extends State<OrganizationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _organizationNameController = TextEditingController();
  final _adminNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  OrganizationType _organizationType = OrganizationType.school;

  @override
  void dispose() {
    _organizationNameController.dispose();
    _adminNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state.status == AuthStatus.failure && state.message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message!)));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Create Organization')),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(24.w),
              children: [
                Text('Set up SmartPresence', style: Theme.of(context).textTheme.headlineLarge),
                SizedBox(height: 8.h),
                Text(
                  'Create the organization workspace and first admin account.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                  ),
                ),
                SizedBox(height: 22.h),
                PremiumCard(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _organizationNameController,
                        decoration: const InputDecoration(labelText: 'Organization Name'),
                        validator: _required,
                      ),
                      SizedBox(height: 14.h),
                      DropdownButtonFormField<OrganizationType>(
                        initialValue: _organizationType,
                        decoration: const InputDecoration(labelText: 'Organization Type'),
                        items: OrganizationType.values
                            .map((type) => DropdownMenuItem(value: type, child: Text(type.label)))
                            .toList(),
                        onChanged: (value) => setState(() => _organizationType = value ?? _organizationType),
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: _adminNameController,
                        decoration: const InputDecoration(labelText: 'Admin Name'),
                        validator: _required,
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Admin Email'),
                        validator: (value) => value == null || !value.contains('@') ? 'Enter a valid email' : null,
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Admin Password'),
                        validator: (value) => value == null || value.length < 6 ? 'Minimum 6 characters' : null,
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Phone Number'),
                        validator: _required,
                      ),
                      SizedBox(height: 14.h),
                      TextFormField(
                        controller: _addressController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: const InputDecoration(labelText: 'Address'),
                        validator: _required,
                      ),
                      SizedBox(height: 22.h),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          return SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: state.status == AuthStatus.checking ? null : _submit,
                              icon: const Icon(Icons.verified_user_rounded),
                              label: Text(state.status == AuthStatus.checking ? 'Creating...' : 'Create Organization'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Required' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    context.read<AuthBloc>().add(
      AuthOrganizationRegistrationRequested(
        OrganizationRegistrationInput(
          organizationName: _organizationNameController.text,
          organizationType: _organizationType,
          adminName: _adminNameController.text,
          adminEmail: _emailController.text,
          adminPassword: _passwordController.text,
          phoneNumber: _phoneController.text,
          address: _addressController.text,
        ),
      ),
    );
  }
}
