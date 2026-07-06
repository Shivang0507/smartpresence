import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../core/enums/user_role.dart';
import '../features/analytics/presentation/screens/analytics_dashboard_screen.dart';
import '../features/attendance/presentation/screens/attendance_scanner_screen.dart';
import '../features/attendance/presentation/screens/attendance_session_screen.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/organization_registration_screen.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/welcome_screen.dart';
import '../features/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../features/dashboard/presentation/screens/role_home_screen.dart';
import '../features/directory/presentation/screens/directory_management_screen.dart';
import '../core/enums/directory_type.dart';
import '../features/shifts/presentation/screens/manage_shifts_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/users/presentation/screens/user_creation_wizard_screen.dart';
import '../features/users/presentation/screens/user_management_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/settings/presentation/screens/organization_details_screen.dart';
import '../features/settings/presentation/screens/theme_settings_screen.dart';
import '../features/settings/presentation/screens/security_screen.dart';
import '../features/settings/presentation/screens/about_screen.dart';

class AppRouter {
  static const splash = '/';
  static const welcome = '/welcome';
  static const login = '/login';
  static const registerOrganization = '/create-organization';
  static const adminDashboard = '/admin';
  static const receptionistHome = '/receptionist';
  static const teacherManagerHome = '/teacher-manager';
  static const memberHome = '/member';
  static const receptionists = '/admin/receptionists';
  static const teachers = '/admin/teachers';
  static const users = '/admin/users';
  static const createUser = '/users/create';
  static const departments = '/admin/departments';
  static const teams = '/admin/teams';
  static const shifts = '/admin/shifts';
  static const attendance = '/attendance/session';
  static const scanner = '/attendance/scanner';
  static const analytics = '/analytics';
  static const reports = '/reports';
  static const settings = '/settings';
  static const profile = '/profile';
  static const settingsOrganization = '/settings/organization';
  static const settingsTheme = '/settings/theme';
  static const settingsSecurity = '/settings/security';
  static const settingsAbout = '/settings/about';

  static GoRouter create({required AuthBloc authBloc, Object? firebaseError}) {
    return GoRouter(
      initialLocation: splash,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => SplashScreen(firebaseError: firebaseError),
        ),
        GoRoute(path: welcome, builder: (context, state) => const WelcomeScreen()),
        GoRoute(path: login, builder: (context, state) => const LoginScreen()),
        GoRoute(
          path: registerOrganization,
          builder: (context, state) => const OrganizationRegistrationScreen(),
        ),
        GoRoute(
          path: adminDashboard,
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: receptionistHome,
          builder: (context, state) => const RoleHomeScreen(role: UserRole.receptionist),
        ),
        GoRoute(
          path: teacherManagerHome,
          builder: (context, state) => const RoleHomeScreen(role: UserRole.teacherManager),
        ),
        GoRoute(
          path: memberHome,
          builder: (context, state) => const RoleHomeScreen(role: UserRole.member),
        ),
        GoRoute(
          path: receptionists,
          builder: (context, state) => const UserManagementScreen(
            title: 'Manage Receptionists',
            roles: [UserRole.receptionist],
          ),
        ),
        GoRoute(
          path: teachers,
          builder: (context, state) => const UserManagementScreen(
            title: 'Manage Teachers',
            roles: [UserRole.teacherManager],
          ),
        ),
        GoRoute(
          path: users,
          builder: (context, state) => const UserManagementScreen(title: 'Manage Users'),
        ),
        GoRoute(
          path: createUser,
          builder: (context, state) {
            final roleVal = state.uri.queryParameters['role'];
            final role = UserRole.fromValue(roleVal ?? UserRole.member.value);
            return UserCreationWizardScreen(role: role);
          },
        ),
        GoRoute(
          path: departments,
          builder: (context, state) => const DirectoryManagementScreen(type: DirectoryType.department),
        ),
        GoRoute(
          path: teams,
          builder: (context, state) => const DirectoryManagementScreen(type: DirectoryType.team),
        ),
        GoRoute(
          path: shifts,
          builder: (context, state) => const ManageShiftsScreen(),
        ),
        GoRoute(
          path: attendance,
          builder: (context, state) => const AttendanceSessionScreen(),
        ),
        GoRoute(
          path: scanner,
          builder: (context, state) => const AttendanceScannerScreen(),
        ),
        GoRoute(
          path: analytics,
          builder: (context, state) => const AnalyticsDashboardScreen(),
        ),
        GoRoute(
          path: reports,
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: settings,
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: settingsOrganization,
          builder: (context, state) => const OrganizationDetailsScreen(),
        ),
        GoRoute(
          path: settingsTheme,
          builder: (context, state) => const ThemeSettingsScreen(),
        ),
        GoRoute(
          path: settingsSecurity,
          builder: (context, state) => const SecurityScreen(),
        ),
        GoRoute(
          path: settingsAbout,
          builder: (context, state) => const AboutScreen(),
        ),
      ],
      redirect: (context, state) {
        final authState = authBloc.state;
        final location = state.matchedLocation;
        final isAuthRoute = location == login || location == registerOrganization || location == welcome;

        if (authState.status == AuthStatus.checking) {
          debugPrint('ROUTER: Checking session. Current location: $location');
          return location == splash ? null : splash;
        }
        if (authState.status == AuthStatus.unauthenticated) {
          final target = isAuthRoute ? null : welcome;
          debugPrint('ROUTING SUCCESS: Redirecting to ${target ?? location}');
          return target;
        }
        if (authState.status == AuthStatus.authenticated) {
          final userRole = authState.user!.role;
          if (location.startsWith(adminDashboard) && userRole != UserRole.admin) {
            final target = _homeForRole(userRole);
            debugPrint('ROUTING SUCCESS: Role mismatch redirect from $location to $target');
            return target;
          }
          if (location == splash || isAuthRoute) {
            final target = _homeForRole(userRole);
            debugPrint('ROUTING SUCCESS: Navigating to $target');
            return target;
          }
          debugPrint('ROUTING SUCCESS: User authenticated, staying on $location');
        }
        return null;
      },
      refreshListenable: GoRouterRefreshStream(authBloc.stream),
    );
  }

  static String _homeForRole(UserRole role) {
    return switch (role) {
      UserRole.admin => adminDashboard,
      UserRole.receptionist => receptionistHome,
      UserRole.teacherManager => teacherManagerHome,
      UserRole.member => memberHome,
    };
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
