import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

/// Covers the app with device authentication when a signed-in mobile app
/// starts or returns from the background.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  static Future<T> runExternalActivity<T>(
    BuildContext context,
    Future<T> Function() activity,
  ) {
    return _AppLockGateScope.runExternalActivity(context, activity);
  }

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();

  String? _lastUserId;
  bool _sessionResolved = false;
  bool _isLocked = false;
  bool _isAuthenticating = false;
  int _externalActivityCount = 0;
  String? _errorMessage;
  DateTime? _lastAuthenticationFinished;

  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (auth.isInitializing) return;

    final userId = auth.user?.id;
    if (!_sessionResolved) {
      _sessionResolved = true;
      _lastUserId = userId;
      if (userId != null && _isSupportedPlatform) {
        _lockAndRequestAuthentication();
      }
      return;
    }

    if (userId == _lastUserId) return;
    final wasSignedIn = _lastUserId != null;
    _lastUserId = userId;

    if (userId == null) {
      _isLocked = false;
      _errorMessage = null;
    } else if (wasSignedIn && _isSupportedPlatform) {
      // Account switching while the app is open should not expose the prior
      // account's screen.
      _lockAndRequestAuthentication();
    }
  }

  void _lockAndRequestAuthentication() {
    _isLocked = true;
    _errorMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_authenticate());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_externalActivityCount > 0) return;
    if (!_isSupportedPlatform || !context.read<AuthProvider>().isAuth) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_isAuthenticating && !_isLocked && mounted) {
        setState(() => _isLocked = true);
      }
      return;
    }

    if (state == AppLifecycleState.resumed &&
        _isLocked &&
        !_isAuthenticating &&
        !_justFinishedAuthentication) {
      unawaited(_authenticate());
    }
  }

  bool get _justFinishedAuthentication {
    final finished = _lastAuthenticationFinished;
    return finished != null &&
        DateTime.now().difference(finished) < const Duration(seconds: 2);
  }

  void _beginExternalActivity() {
    _externalActivityCount++;
  }

  void _endExternalActivity() {
    _externalActivityCount--;
  }

  Future<void> _authenticate() async {
    if (!_isSupportedPlatform || _isAuthenticating || !_isLocked || !mounted) {
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Desbloqueie o No Bolso para acessar suas finanças.',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (mounted && authenticated) {
        setState(() => _isLocked = false);
      } else if (mounted) {
        setState(
          () => _errorMessage = 'Autenticação cancelada. Tente novamente.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Não foi possível autenticar. Tente novamente ou saia da conta.',
        );
      }
    } finally {
      _lastAuthenticationFinished = DateTime.now();
      if (mounted) setState(() => _isAuthenticating = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isLocked = _isSupportedPlatform && auth.isAuth && _isLocked;

    return _AppLockGateScope(
      onActivityStarted: _beginExternalActivity,
      onActivityFinished: _endExternalActivity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          if (isLocked)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_person_rounded,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Bolso bloqueado',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ??
                                'Confirme sua identidade para continuar.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _isAuthenticating ? null : _authenticate,
                            icon: _isAuthenticating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              _isAuthenticating
                                  ? 'Verificando…'
                                  : 'Desbloquear',
                            ),
                          ),
                          TextButton(
                            onPressed: _isAuthenticating ? null : auth.signOut,
                            child: const Text('Sair da conta'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AppLockGateScope extends InheritedWidget {
  const _AppLockGateScope({
    required this.onActivityStarted,
    required this.onActivityFinished,
    required super.child,
  });

  final VoidCallback onActivityStarted;
  final VoidCallback onActivityFinished;

  static Future<T> runExternalActivity<T>(
    BuildContext context,
    Future<T> Function() activity,
  ) async {
    final scope = context.getInheritedWidgetOfExactType<_AppLockGateScope>();
    scope?.onActivityStarted();
    try {
      return await activity();
    } finally {
      scope?.onActivityFinished();
    }
  }

  @override
  bool updateShouldNotify(_AppLockGateScope oldWidget) => false;
}
