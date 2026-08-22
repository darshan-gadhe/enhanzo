import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// The app's one way to show a transient message.
///
/// Exists for two reasons a raw [SnackBar] can't cover:
///
/// * **It clears the floating navigation bar.** A `floating` snackbar sits at
///   `bottom: 0`, which is exactly where [AppSizing.navBarHeight] of translucent
///   nav already is — the message lands underneath it. Every snackbar here is
///   lifted above the bar plus the bottom safe-area inset.
/// * **It never stacks.** The previous message is dismissed first, so a rapid
///   sequence of actions doesn't queue messages the user has to sit through.
class AppSnack {
  AppSnack._();

  /// Gap between the snackbar and whatever sits below it.
  static const double _clearance = AppSpacing.x12;

  /// Shows [message] above the navigation bar.
  ///
  /// Pass `overlay: true` from a full-screen step that hides the nav (the edit
  /// flow, the generator, the paywall) so the message isn't floating in dead
  /// space where no nav bar exists.
  static void show(
    BuildContext context,
    String message, {
    bool overlay = false,
    SnackBarAction? action,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final lift = overlay
        ? bottomInset + _clearance
        : bottomInset + AppSizing.navBarHeight + _clearance;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          action: action,
          margin: EdgeInsets.fromLTRB(
            AppSpacing.x16,
            0,
            AppSpacing.x16,
            lift,
          ),
        ),
      );
  }

  /// Captures everything [show] needs *now* and returns a closure that can be
  /// called later, once the current [BuildContext] is gone.
  ///
  /// For the "dismiss a sheet, then report what happened" pattern: popping a
  /// route unmounts the element the sheet built from, so reading
  /// `ScaffoldMessenger.of(context)` or `MediaQuery.of(context)` afterwards is
  /// use-after-dispose. Grab the closure before the pop, call it after:
  ///
  /// ```dart
  /// final notify = AppSnack.deferred(context);
  /// Navigator.of(context).pop();
  /// notify('Edit deleted');
  /// ```
  static void Function(String message) deferred(
    BuildContext context, {
    bool overlay = false,
  }) {
    final show = _defer(context, overlay: overlay);
    return (message) => show(message, null);
  }

  /// [deferred] for an action that can be taken back.
  ///
  /// Same deal — capture before the pop, call after — but the returned closure
  /// also carries an action, so a destructive step can offer an undo instead of
  /// stopping the user with a confirmation dialog first.
  ///
  /// ```dart
  /// final undo = AppSnack.undoable(context);
  /// Navigator.of(context).pop();
  /// history.remove(id);
  /// undo('Edit deleted', actionLabel: 'Undo', onAction: () => history.restore(entry, index));
  /// ```
  static void Function(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
  })
  undoable(BuildContext context, {bool overlay = false}) {
    final show = _defer(context, overlay: overlay);
    return (message, {required actionLabel, required onAction}) => show(
      message,
      SnackBarAction(label: actionLabel, onPressed: onAction),
    );
  }

  /// Reads everything context-dependent up front and returns the presenter both
  /// deferred forms share.
  static void Function(String message, SnackBarAction? action) _defer(
    BuildContext context, {
    required bool overlay,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final lift = overlay
        ? bottomInset + _clearance
        : bottomInset + AppSizing.navBarHeight + _clearance;

    return (message, action) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            behavior: SnackBarBehavior.floating,
            action: action,
            margin: EdgeInsets.fromLTRB(
              AppSpacing.x16,
              0,
              AppSpacing.x16,
              lift,
            ),
          ),
        );
    };
  }
}
