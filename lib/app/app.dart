import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_cubit.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import 'app_router.dart';

class SmartPresenceApp extends StatefulWidget {
  const SmartPresenceApp({super.key, this.firebaseError});

  final Object? firebaseError;

  @override
  State<SmartPresenceApp> createState() => _SmartPresenceAppState();
}

class _SmartPresenceAppState extends State<SmartPresenceApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.create(
      authBloc: context.read<AuthBloc>(),
      firebaseError: widget.firebaseError,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeCubit(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp.router(
                title: 'SmartPresence',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: themeMode,
                routerConfig: _router,
              );
            },
          );
        },
      ),
    );
  }
}
