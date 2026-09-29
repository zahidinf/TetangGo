import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/waiting_verification_screen.dart';
import '../../features/home/presentation/adaptive_dashboard_screen.dart';
import 'refresh_stream.dart';

GoRouter createAppRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final currentPath = state.uri.path;

      final isSplash = currentPath == '/';
      final isLogin = currentPath == '/login';
      final isRegister = currentPath == '/register';
      final isWaiting = currentPath == '/waiting-verification';

      // 1. Initial / Loading state -> Stay on Splash screen
      if (authState.status == AuthStatus.initial || authState.status == AuthStatus.loading) {
        return isSplash ? null : '/';
      }

      // 2. Unauthenticated or Failure -> Allow /login and /register
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      if (!isLoggedIn) {
        if (isLogin || isRegister) {
          return null;
        }
        return '/login';
      }

      final user = authState.user;

      // 3. User berstatus pending verification -> Arahkan ke waiting verification
      if (user != null && user.isPending) {
        return isWaiting ? null : '/waiting-verification';
      }

      // 4. User aktif -> Jangan biarkan masuk ke login, register, splash, atau waiting verification
      if (isLogin || isRegister || isSplash || isWaiting) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return const LoginScreen();
        },
      ),
      GoRoute(
        path: '/register',
        builder: (BuildContext context, GoRouterState state) {
          return const RegisterScreen();
        },
      ),
      GoRoute(
        path: '/waiting-verification',
        builder: (BuildContext context, GoRouterState state) {
          return const WaitingVerificationScreen();
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (BuildContext context, GoRouterState state) {
          return const AdaptiveDashboardScreen();
        },
      ),
    ],
  );
}
