import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartpresence/features/auth/presentation/screens/welcome_screen.dart';

void main() {
  testWidgets('welcome screen exposes organization-first entry points', (
    tester,
  ) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (context, child) {
          return const MaterialApp(home: WelcomeScreen());
        },
      ),
    );

    expect(
      find.text('Smart Attendance & Workforce Management Platform'),
      findsOneWidget,
    );
    expect(find.text('Login'), findsOneWidget);
    expect(find.byIcon(Icons.login_rounded), findsOneWidget);
    expect(find.text('Create Organization'), findsOneWidget);
    expect(find.byIcon(Icons.domain_add_rounded), findsOneWidget);
  });
}
