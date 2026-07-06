import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/widgets/sp_logo.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SpLogo(size: 52, showWordmark: true),
              SizedBox(height: 48.h),

              // Headline — always white on the dark background
              Text(
                'Smart Attendance\n& Workforce\nManagement',
                style: tt.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                'Built for every organization type.',
                style: tt.bodyLarge?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),

              const Spacer(),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.push(AppRouter.login),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Login'),
                ),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRouter.registerOrganization),
                  icon: const Icon(Icons.domain_add_rounded),
                  label: const Text('Create Organization'),
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
