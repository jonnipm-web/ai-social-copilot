import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/biometric_auth_service.dart';
import '../../../providers/biometric_auth_provider.dart';

/// Offer to enable biometric login right after a successful password sign-in.
/// Must be shown with showModalBottomSheet.
class BiometricEnrollmentSheet extends ConsumerStatefulWidget {
  const BiometricEnrollmentSheet({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<BiometricEnrollmentSheet> createState() =>
      _BiometricEnrollmentSheetState();
}

class _BiometricEnrollmentSheetState
    extends ConsumerState<BiometricEnrollmentSheet> {
  bool _loading = false;
  String? _error;

  Future<void> _activate() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final service = ref.read(biometricAuthServiceProvider);
    final status = await service.enable(
      localizedReason: 'Confirme sua digital para ativar o login biométrico',
      userId: widget.userId,
    );

    if (!mounted) return;

    switch (status) {
      case BiometricStatus.success:
        ref.invalidate(biometricEnabledProvider);
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Login biométrico ativado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      case BiometricStatus.userCancel:
        Navigator.of(context).pop(false);
      case BiometricStatus.lockout:
        setState(() {
          _loading = false;
          _error = 'Muitas tentativas. Aguarde e tente novamente.';
        });
      case BiometricStatus.lockoutPermanent:
        setState(() {
          _loading = false;
          _error = 'Biometria bloqueada. Desbloqueie o dispositivo primeiro.';
        });
      case BiometricStatus.noneEnrolled:
        setState(() {
          _loading = false;
          _error = 'Nenhuma biometria cadastrada no dispositivo.';
        });
      default:
        setState(() {
          _loading = false;
          _error = 'Não foi possível ativar. Tente novamente mais tarde.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(Icons.fingerprint_rounded, size: 56, color: primary),
            const SizedBox(height: 16),
            Text(
              'Ativar login biométrico?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nas próximas entradas, use sua digital ou face para acessar '
              'o app sem digitar senha.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade300, fontSize: 13),
              ),
            ],
            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white54,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      child: const Text('Agora não'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _activate,
                      icon: const Icon(Icons.fingerprint_rounded, size: 18),
                      label: const Text('Ativar'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
