import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/app_user.dart';
import '../../data/auth_repository.dart';

enum AuthStatus { checking, authenticated, unauthenticated, failure }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.message,
  });

  const AuthState.checking() : this(status: AuthStatus.checking);

  const AuthState.unauthenticated([String? message])
    : this(status: AuthStatus.unauthenticated, message: message);

  const AuthState.authenticated(AppUser user)
    : this(status: AuthStatus.authenticated, user: user);

  const AuthState.failure(String message) : this(status: AuthStatus.failure, message: message);

  final AuthStatus status;
  final AppUser? user;
  final String? message;
}

sealed class AuthEvent {}

class AuthSessionRequested extends AuthEvent {}

class AuthLoginRequested extends AuthEvent {
  AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;
}

class AuthOrganizationRegistrationRequested extends AuthEvent {
  AuthOrganizationRegistrationRequested(this.input);

  final OrganizationRegistrationInput input;
}

class AuthLogoutRequested extends AuthEvent {}

class _AuthSessionChanged extends AuthEvent {
  _AuthSessionChanged(this.user);

  final AppUser? user;
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._authRepository) : super(const AuthState.checking()) {
    on<AuthSessionRequested>(_onSessionRequested);
    on<_AuthSessionChanged>(_onSessionChanged);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthOrganizationRegistrationRequested>(_onRegistrationRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final AuthRepository _authRepository;
  StreamSubscription<AppUser?>? _sessionSubscription;

  Future<void> _onSessionRequested(AuthSessionRequested event, Emitter<AuthState> emit) async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = _authRepository.watchSession().listen(
      (user) => add(_AuthSessionChanged(user)),
      onError: (Object error) {
        debugPrint('AUTH SESSION STREAM ERROR: $error');
        // Do not sign out already authenticated users on transient stream errors
        if (state.status != AuthStatus.authenticated) {
          add(_AuthSessionChanged(null));
        }
      },
    );
  }

  void _onSessionChanged(_AuthSessionChanged event, Emitter<AuthState> emit) {
    final user = event.user;
    emit(user == null ? const AuthState.unauthenticated() : AuthState.authenticated(user));
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(const AuthState.checking());
    try {
      final user = await _authRepository.login(email: event.email, password: event.password);
      emit(AuthState.authenticated(user));
    } catch (error, stackTrace) {
      debugPrint('ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(AuthState.failure(error.toString()));
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onRegistrationRequested(
    AuthOrganizationRegistrationRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.checking());
    try {
      final user = await _authRepository.registerOrganization(event.input);
      emit(AuthState.authenticated(user));
    } catch (error, stackTrace) {
      debugPrint('ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      emit(AuthState.failure(error.toString()));
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _authRepository.logout();
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }
}
