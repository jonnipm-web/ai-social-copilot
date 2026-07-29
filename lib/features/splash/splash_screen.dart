import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _redirect();
  }

  Future<void> _redirect() async {
    // Supabase restores the persisted session asynchronously from secure storage
    // on cold start. We listen for the first auth event to avoid the race where
    // currentSession is null even though a valid token exists.
    final completer = Completer<Session?>();
    late final StreamSubscription<AuthState> sub;
    sub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!completer.isCompleted) {
        completer.complete(data.session);
      }
      sub.cancel();
    });

    final session = await completer.future.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        sub.cancel();
        return Supabase.instance.client.auth.currentSession;
      },
    );

    if (!mounted) return;
    context.go(
      session != null ? AppConstants.routeDashboard : AppConstants.routeLogin,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
