import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_info.dart';
import 'data/replicate/replicate_config.dart';
import 'screens/app_shell.dart';
import 'state/app_state.dart';
import 'theme/theme.dart';

void main() {
  // Fails a release build that was compiled without
  // `--dart-define-from-file=.env`. Those defines are compile-time and vanish
  // silently when the flag is missed: the build still succeeds and still
  // signs, and the resulting app cannot enhance a single photo. A bundle in
  // exactly that state was already installed once, showing users an error
  // where the product should have been.
  //
  // Deliberately *before* runApp and deliberately not caught: this is a build
  // mistake, not a runtime condition to degrade around, and it must be
  // impossible to miss. No-op in debug and profile, where the app is meant to
  // run credential-free on its simulated pipeline.
  ReplicateConfig.assertConfigured();

  runApp(const ProviderScope(child: EnhanzoApp()));
}

class EnhanzoApp extends ConsumerWidget {
  const EnhanzoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final dark = mode == ThemeMode.dark;

    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      builder: (context, child) {
        // Keep the platform status-bar icons legible against the current theme.
        //
        // Declared rather than pushed: this used to call
        // `SystemChrome.setSystemUIOverlayStyle` directly inside `build`, which
        // is a side effect fired on every rebuild and never undone. An
        // AnnotatedRegion ties the style to what is actually on screen, so the
        // framework applies and restores it as the tree changes.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
          // Expose the resolved surface palette to the whole tree.
          child: PaletteScope(
            palette: dark ? AppPalette.dark : AppPalette.light,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const AppShell(),
    );
  }
}
