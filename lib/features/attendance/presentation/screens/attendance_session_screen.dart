import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/widgets/premium_card.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/attendance_models.dart';
import '../../data/attendance_repository.dart';

class AttendanceSessionScreen extends StatefulWidget {
  const AttendanceSessionScreen({super.key});

  @override
  State<AttendanceSessionScreen> createState() => _AttendanceSessionScreenState();
}

class _AttendanceSessionScreenState extends State<AttendanceSessionScreen> {
  final _repository = AttendanceRepository();
  String? _sessionId;
  bool _starting = false;
  bool _fullscreenQr = false;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthBloc>().state.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance Session')),
      body: SafeArea(
        child: user == null
            ? const Center(child: Text('No active user profile found.'))
            : _sessionId == null
                ? _StartSessionPanel(
                    starting: _starting,
                    onStart: () => _start(user.organizationId),
                  )
                : StreamBuilder<AttendanceSession>(
                    stream: _repository.watchSession(_sessionId!),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final session = snapshot.data!;
                      return _fullscreenQr
                          ? _FullscreenQr(
                              session: session,
                              onClose: () => setState(() => _fullscreenQr = false),
                            )
                            : _SessionDashboard(
                                session: session,
                                liveCount: _repository.watchLiveCount(
                                  organizationId: session.organizationId,
                                  sessionId: session.id,
                                ),
                                onFullscreen: () => setState(() => _fullscreenQr = true),
                                onEnd: () => _repository.endSession(session.id),
                              );
                    },
                  ),
      ),
    );
  }

  Future<void> _start(String organizationId) async {
    setState(() => _starting = true);
    try {
      final id = await _repository.startSession(organizationId: organizationId);
      if (mounted) {
        setState(() {
          _sessionId = id;
          _starting = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start attendance: $error')),
        );
      }
    }
  }
}

class _StartSessionPanel extends StatelessWidget {
  const _StartSessionPanel({required this.starting, required this.onStart});

  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520.w),
        child: PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.qr_code_2_rounded, size: 64.w, color: Theme.of(context).colorScheme.primary),
              SizedBox(height: 16.h),
              Text('Start Dynamic QR Attendance', style: Theme.of(context).textTheme.headlineSmall),
              SizedBox(height: 8.h),
              Text(
                'A secure session token is embedded in the QR and rotates after every successful QR + face attendance.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.64),
                    ),
              ),
              SizedBox(height: 22.h),
              FilledButton.icon(
                onPressed: starting ? null : onStart,
                icon: starting
                    ? SizedBox.square(dimension: 16.w, child: const CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(starting ? 'Starting...' : 'Start Session'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionDashboard extends StatelessWidget {
  const _SessionDashboard({
    required this.session,
    required this.liveCount,
    required this.onFullscreen,
    required this.onEnd,
  });

  final AttendanceSession session;
  final Stream<int> liveCount;
  final VoidCallback onFullscreen;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(20.w),
      children: [
        PremiumCard(
          child: Column(
            children: [
              QrImageView(
                data: session.qrPayload,
                version: QrVersions.auto,
                size: 260.w,
                backgroundColor: Colors.white,
              ),
              SizedBox(height: 14.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: onFullscreen,
                    icon: const Icon(Icons.fullscreen_rounded),
                    label: const Text('Fullscreen'),
                  ),
                  OutlinedButton.icon(
                    onPressed: session.status == 'active' ? onEnd : null,
                    icon: const Icon(Icons.stop_circle_rounded),
                    label: const Text('End Session'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 14.h),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Live Attendance',
                stream: liveCount,
                icon: Icons.people_alt_rounded,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _StatusCard(status: session.status),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.stream, required this.icon});

  final String label;
  final Stream<int> stream;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: StreamBuilder<int>(
        stream: stream,
        builder: (context, snapshot) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              SizedBox(height: 12.h),
              Text('${snapshot.data ?? 0}', style: Theme.of(context).textTheme.headlineMedium),
              Text(label),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_rounded, color: Theme.of(context).colorScheme.secondary),
          SizedBox(height: 12.h),
          Text(status.toUpperCase(), style: Theme.of(context).textTheme.titleLarge),
          const Text('Session Status'),
        ],
      ),
    );
  }
}

class _FullscreenQr extends StatelessWidget {
  const _FullscreenQr({required this.session, required this.onClose});

  final AttendanceSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: session.qrPayload,
              version: QrVersions.auto,
              size: min(MediaQuery.sizeOf(context).width, MediaQuery.sizeOf(context).height) * 0.68,
              backgroundColor: Colors.white,
            ),
            SizedBox(height: 18.h),
            FilledButton.icon(
              onPressed: onClose,
              icon: const Icon(Icons.close_fullscreen_rounded),
              label: const Text('Exit Fullscreen'),
            ),
          ],
        ),
      ),
    );
  }
}
