import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:brightspeed_fiber_app/core/location/location_tracking_service.dart';
import 'package:brightspeed_fiber_app/core/navigation/app_navigator_key.dart';
import 'package:brightspeed_fiber_app/core/network/connectivity_status_service.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_dialog_host.dart';
import 'package:brightspeed_fiber_app/core/notifications/notification_inbox_service.dart';
import 'package:brightspeed_fiber_app/core/theme/app_theme.dart';

import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_cubit.dart';
import 'package:brightspeed_fiber_app/presentation/auth/cubit/auth_state.dart';
import 'package:brightspeed_fiber_app/presentation/auth/pages/login_page.dart';
import 'package:brightspeed_fiber_app/presentation/auth/pages/password_page.dart';
import 'package:brightspeed_fiber_app/presentation/home/pages/home_page.dart';
import 'package:brightspeed_fiber_app/presentation/jobs/cubit/jobs_cubit.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(
    RouteSettings settings,
  ) {
    switch (settings.name) {
      case LoginPage.routeName:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginPage(),
        );

      case PasswordPage.routeName:
        final username = settings.arguments as String? ?? '';

        return MaterialPageRoute<void>(
          settings: settings,q
          builder: (_) => PasswordPage(
            username: username,
          ),
        );

      case HomePage.routeName:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HomePage(),
        );

      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const LoginPage(),
        );
    }
  }
}

class TechMateApp extends StatefulWidget {
  const TechMateApp({super.key});

  @override
  State<TechMateApp> createState() => _TechMateAppState();
}

class _TechMateAppState extends State<TechMateApp> with WidgetsBindingObserver {
  static const String _gpsDialogRouteName = 'gps_disabled_dialog';

  bool _gpsDialogShowing = false;
  bool _leftForeground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final locationTrackingService = context.read<LocationTrackingService>();

    locationTrackingService.onGpsDisabled = () {
      debugPrint('APP: GPS DISABLED CALLBACK RECEIVED');
      unawaited(_showGpsDialog());
    };
    locationTrackingService.onGpsEnabled = () {
      debugPrint('APP: GPS ENABLED CALLBACK RECEIVED');
      _dismissGpsDialog();
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftForeground = true;
      return;
    }

    if (state != AppLifecycleState.resumed || !_leftForeground) {
      return;
    }

    _leftForeground = false;
    unawaited(_handleAppResumed());
  }

  Future<void> _handleAppResumed() async {
    debugPrint('APP: resumed — rechecking GPS');

    final locationTrackingService = context.read<LocationTrackingService>();
    final connectivityStatusService =
        context.read<ConnectivityStatusService>();
    final authCubit = context.read<AuthCubit>();
    final jobsCubit = context.read<JobsCubit>();

    unawaited(locationTrackingService.handleAppResumed());
    // Connectivity changes while backgrounded may not reach the stream.
    // Sync runs only on offline → online inside JobsSyncService.
    await connectivityStatusService.refresh();

    if (!connectivityStatusService.isOnline) {
      if (!mounted) {
        return;
      }

      final authState = authCubit.state;
      if (authState.status == AuthStatus.authenticated &&
          authState.session != null) {
        await jobsCubit.refreshJobStatusOnResume(authState.session!.userId);
      }
    }
  }

  void _dismissGpsDialog() {
    if (!_gpsDialogShowing) {
      return;
    }

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return;
    }

    // Pop only while the GPS dialog is the current route.
    navigator.popUntil((route) {
      return route.settings.name != _gpsDialogRouteName;
    });
  }

  Future<void> _showGpsDialog() async {
    if (!mounted) {
      return;
    }

    if (_gpsDialogShowing) {
      return;
    }

    _gpsDialogShowing = true;

    debugPrint('APP: Showing GPS disabled dialog');

    final locationTrackingService = context.read<LocationTrackingService>();

    try {
      BuildContext? navContext;
      for (var attempt = 0; attempt < 40; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(
            const Duration(milliseconds: 100),
          );
        }
        if (!_gpsDialogShowing) {
          return;
        }
        navContext = appNavigatorKey.currentContext;
        if (navContext != null && navContext.mounted) {
          break;
        }
      }

      if (!_gpsDialogShowing) {
        return;
      }

      if (navContext == null || !navContext.mounted) {
        debugPrint('APP: GPS dialog skipped — navigator not ready');
        if (!mounted) {
          return;
        }
        context.read<LocationTrackingService>().resetGpsDisabledPrompt();
        return;
      }

      if (!mounted) {
        return;
      }

      final shouldPrompt = await locationTrackingService.shouldPromptForGps();
      if (!shouldPrompt ||
          !_gpsDialogShowing ||
          !mounted ||
          !navContext.mounted) {
        locationTrackingService.resetGpsDisabledPrompt();
        return;
      }

      await showDialog<void>(
        context: navContext,
        barrierDismissible: false,
        useRootNavigator: true,
        routeSettings: const RouteSettings(
          name: _gpsDialogRouteName,
        ),
        builder: (dialogContext) {
          return PopScope(
            canPop: false,
            child: AlertDialog(
              title: const Text('Location is turned off'),
              content: const Text(
                'Please enable location/GPS to continue using the app.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    unawaited(
                      context.read<LocationTrackingService>().openGpsSettings(),
                    );
                  },
                  child: const Text('Go to Settings'),
                ),
              ],
            ),
          );
        },
      );
    } finally {
      _gpsDialogShowing = false;

      // Dismissing via "Cancel" must not silence the prompt while GPS is
      // still off — the periodic checker can raise it again.
      if (mounted) {
        final stillOff = await locationTrackingService.shouldPromptForGps();
        if (stillOff) {
          locationTrackingService.resetGpsDisabledPrompt();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TechMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: appNavigatorKey,
      onGenerateRoute: AppRouter.onGenerateRoute,
      builder: (context, child) {
        return NotificationDialogHost(
          inboxService: context.read<NotificationInboxService>(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.initial:
          case AuthStatus.loading:
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );

          case AuthStatus.authenticated:
            return const HomePage();

          case AuthStatus.unauthenticated:
            return const LoginPage();
        }
      },
    );
  }
}
