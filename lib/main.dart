import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/app_info.dart';
import 'screens/app_shell.dart';
import 'state/app_state.dart';
import 'theme/theme.dart';

void main() {
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
