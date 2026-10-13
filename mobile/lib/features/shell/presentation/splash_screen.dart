import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/paw_states.dart';
import '../../auth/presentation/brand_mark.dart';

/// Arranque: comprueba la sesión. Si no hay red, permite reintentar sin perder la sesión.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PawSpacing.screen),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const BrandMark(),
              const SizedBox(height: PawSpacing.s32),
              if (session is SessionUnavailable)
                PawErrorState(
                  title: 'No pudimos conectar',
                  message: session.message,
                  onRetry: () => ref.read(sessionProvider.notifier).restore(),
                )
              else
                const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}
