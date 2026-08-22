import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../data/replicate/enhance_job.dart';
import '../data/replicate/real_esrgan.dart';
import '../data/replicate/replicate_client.dart';
import '../data/replicate/replicate_config.dart';
import '../data/revenuecat/revenuecat_service.dart';
import '../data/theme_store.dart';
import '../models/models.dart';
import '../widgets/demo_image.dart';

/// Top-level navigation destinations (the persistent tabs + paywall).
///
/// There is no longer a Tools tab: every tool now lives on Home (a 2×2 of the
/// marquee tools over a single-column list of the rest), so a second tab that
/// listed the same catalog was a duplicate door into one room.
/// There is no `premium` destination: RevenueCat's hosted paywall is presented
/// as a native modal over whatever screen the user is on (see
/// `lib/widgets/paywall.dart`), not as a route this app navigates to.
enum AppScreen { home, history, profile }

/// Steps of the modal edit flow. `null` means no flow is active.
///
/// [error] is the failure surface for a processing job. It is unreachable in
/// this build — the simulated pipeline always succeeds — but wired to
/// [FlowController.fail] so a real inference backend has an honest place to land
/// when a job fails.
enum EditFlow { crop, tool, processing, result, error }

/// Theme mode. Driven by the Settings > Appearance toggle and persisted across
/// launches via [ThemeStore].
///
/// The app defaults to light and loads any saved choice asynchronously after
/// `build()` returns — so the first frame is light and flips to the stored
/// theme once storage answers, rather than blocking startup on disk. Every
/// change is written back best-effort.
class ThemeController extends Notifier<ThemeMode> {
  bool _disposed = false;

  @override
  ThemeMode build() {
    ref.onDispose(() => _disposed = true);
    _restoreFromStorage();
    return ThemeMode.light;
  }

  /// Loads the persisted preference without blocking `build()`. A null result
  /// (first launch or a read error) leaves the default light theme in place.
  Future<void> _restoreFromStorage() async {
    final isDark = await ThemeStore.readIsDark();
    if (_disposed || isDark == null) return;
    state = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  void set(ThemeMode mode) {
    state = mode;
    ThemeStore.writeIsDark(mode == ThemeMode.dark);
  }

  void toggle() =>
      set(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
}

final themeModeProvider = NotifierProvider<ThemeController, ThemeMode>(
  ThemeController.new,
);

/// Currently visible top-level screen.
///
/// The "remember where we came from" machinery this used to carry existed only
/// so the paywall's back button could return there. RevenueCat's paywall is a
/// native modal that dismisses itself onto the screen underneath, so there is
/// nothing left to remember.
class ScreenController extends Notifier<AppScreen> {
  @override
  AppScreen build() => AppScreen.home;

  void go(AppScreen screen) => state = screen;
}

final screenProvider = NotifierProvider<ScreenController, AppScreen>(
  ScreenController.new,
);

/// Immutable snapshot of the modal edit flow.
@immutable
class FlowState {
  final EditFlow? step;
  final String tool;
  final double progress; // 0..100
  final double comparePos; // 3..97

  /// The photo the user picked, straight from the library or camera. Null in
  /// the simulated pipeline (see [FlowController]), where the flow runs on the
  /// bundled demo imagery instead.
  final File? photo;

  /// Width ÷ height of [photo], read once when it is picked so the crop step's
  /// "Free" frame can mean the photo's own proportions.
  final double? photoAspect;

  /// The cropped file that was actually uploaded — the "before" of the result
  /// comparison, so the two sides always show the same framing.
  final File? source;

  /// The model's output, saved on the device.
  final File? result;

  /// What the model was asked for, e.g. `4x · Faces`. Shown on the result
  /// screen and stored on the history entry in place of an export size the app
  /// never applied.
  final String? outputLabel;

  /// Current stage of a running job, for the processing screen's caption and
  /// progress ceiling. Null while the simulated pipeline runs.
  final EnhancePhase? phase;

  /// Why the last run failed, shown on the error step.
  final String? failure;

  /// True when the flow began from a tool tile, so the tool was already decided
  /// and the picker step was skipped.
  ///
  /// Retracing the user's steps needs this: after crop, a preset flow goes
  /// straight to processing, so backing out of processing must return to crop —
  /// returning to a picker the user never passed through would invent a step.
  final bool toolPreset;

  /// The frame chosen on the crop step, carried through to the result.
  final CropRatio cropRatio;

  const FlowState({
    this.step,
    this.tool = '',
    this.progress = 0,
    this.comparePos = 56,
    this.toolPreset = false,
    this.cropRatio = CropRatio.portrait,
    this.photo,
    this.photoAspect,
    this.source,
    this.result,
    this.outputLabel,
    this.phase,
    this.failure,
  });

  String get displayTool => tool.isEmpty ? 'AI Enhance' : tool;

  /// True when this flow is working on a real photo through a real model, as
  /// opposed to the bundled demo imagery.
  bool get isLive => photo != null && ReplicateConfig.isConfigured;

  /// Proportions every canvas in the flow lays out with.
  ///
  /// [CropRatio.free] has no ratio of its own: with a real photo it means that
  /// photo's shape, and only without one does it fall back to the prototype's
  /// default frame.
  double get displayRatio =>
      cropRatio.value ?? photoAspect ?? CropRatio.portrait.value!;

  FlowState copyWith({
    EditFlow? step,
    bool clearStep = false,
    String? tool,
    double? progress,
    double? comparePos,
    bool? toolPreset,
    CropRatio? cropRatio,
    File? photo,
    double? photoAspect,
    File? source,
    File? result,
    String? outputLabel,
    EnhancePhase? phase,
    String? failure,
    /// Drops the previous run's output, phase and failure — what starting or
    /// retrying a job has to do before it can report its own.
    bool clearRun = false,
  }) {
    return FlowState(
      step: clearStep ? null : (step ?? this.step),
      tool: tool ?? this.tool,
      progress: progress ?? this.progress,
      comparePos: comparePos ?? this.comparePos,
      toolPreset: toolPreset ?? this.toolPreset,
      cropRatio: cropRatio ?? this.cropRatio,
      photo: photo ?? this.photo,
      photoAspect: photoAspect ?? this.photoAspect,
      source: clearRun ? source : (source ?? this.source),
      result: clearRun ? result : (result ?? this.result),
      outputLabel: clearRun ? outputLabel : (outputLabel ?? this.outputLabel),
      phase: clearRun ? phase : (phase ?? this.phase),
      failure: clearRun ? failure : (failure ?? this.failure),
    );
  }
}

/// Drives the crop → (tool) → processing → result sequence.
///
/// Processing takes one of two paths:
///
/// * **Live** — a real photo plus a configured [ReplicateConfig] and a tool
///   [RealEsrgan] implements. The photo is cropped, uploaded, run through the
///   model and downloaded by an [EnhanceJob]; progress reports the stage the
///   job is genuinely in.
/// * **Simulated** — the prototype's original timer, kept for builds with no
///   API token (and for tests), so the app still demonstrates the flow end to
///   end on its bundled imagery.
///
/// A live tool the model does not implement fails loudly rather than falling
/// back to the simulation: showing a demo "result" for a photo the user
/// supplied would be a lie about what the app just did.
class FlowController extends Notifier<FlowState> {
  Timer? _timer;
  bool _disposed = false;
  final _rand = Random();

  /// The running job, if any. Held so backing out can cancel it.
  EnhanceJob? _job;

  @override
  FlowState build() {
    ref.onDispose(() {
      _disposed = true;
      _stopJob();
    });
    return const FlowState();
  }

  /// FAB / big upload button: start with no tool chosen yet.
  ///
  /// [photo] is the picked source; leaving it null runs the simulated pipeline.
  void startUpload({File? photo, double? photoAspect}) {
    _stopJob();
    state = FlowState(
      step: EditFlow.crop,
      tool: '',
      photo: photo,
      photoAspect: photoAspect,
    );
  }

  /// A tool tile was tapped somewhere in the app.
  void pickTool(String tool, {File? photo, double? photoAspect}) {
    _stopJob();
    state = FlowState(
      step: EditFlow.crop,
      tool: tool,
      toolPreset: true,
      photo: photo,
      photoAspect: photoAspect,
    );
  }

  /// Attaches (or replaces) the photo the flow is working on.
  ///
  /// The upload control on the crop step calls this. Replacing a photo drops
  /// anything the previous one produced, so a finished result can never be
  /// shown alongside a different source than the one that made it.
  /// Built rather than copied: a new photo brings its own proportions, and
  /// `copyWith` would keep the previous photo's whenever this one can't be
  /// measured. Everything a run produces resets with it.
  void setPhoto(File photo, {double? aspect}) {
    _stopJob();
    state = FlowState(
      step: state.step,
      tool: state.tool,
      toolPreset: state.toolPreset,
      cropRatio: state.cropRatio,
      photo: photo,
      photoAspect: aspect,
    );
  }

  void cropNext() {
    if (state.tool.isNotEmpty) {
      _beginProcessing();
    } else {
      state = state.copyWith(step: EditFlow.tool);
    }
  }

  void chooseTool(String tool) {
    state = state.copyWith(tool: tool);
    _beginProcessing();
  }

  void setCropRatio(CropRatio ratio) =>
      state = state.copyWith(cropRatio: ratio);

  void applyAnother() {
    _stopJob();
    state = state.copyWith(
      step: EditFlow.tool,
      progress: 0,
      comparePos: 56,
      clearRun: true,
    );
  }

  void setComparePos(double pos) =>
      state = state.copyWith(comparePos: pos.clamp(3, 97));

  /// Retreats one step, for the system back gesture.
  ///
  /// Back is not "cancel": it undoes the last decision and leaves the earlier
  /// ones intact, so a mis-tap costs one step rather than the whole flow. Only
  /// the first step has nothing behind it, and there back does close.
  void back() {
    // Where a finished or abandoned job returns to: the picker if the user
    // chose the tool mid-flow, otherwise the crop step they came from.
    final beforeProcessing = state.toolPreset ? EditFlow.crop : EditFlow.tool;

    switch (state.step) {
      // A running job has no partial state worth keeping, so backing out of
      // processing, its result, or a failure rewinds to the same place.
      case EditFlow.result:
      case EditFlow.processing:
      case EditFlow.error:
        _stopJob();
        state = state.copyWith(
          step: beforeProcessing,
          progress: 0,
          comparePos: 56,
          clearRun: true,
        );
      case EditFlow.tool:
        state = state.copyWith(step: EditFlow.crop);
      case EditFlow.crop:
      case null:
        close();
    }
  }

  void close() {
    _stopJob();
    state = const FlowState();
  }

  /// Re-runs a job from the start after a failure — the error step's "Try
  /// again". The source photo and chosen tool are untouched, so this simply
  /// restarts processing.
  void retry() => _beginProcessing();

  /// Moves a running job to the [EditFlow.error] step, carrying [message] to
  /// the screen so a failure says what went wrong rather than only that
  /// something did.
  ///
  /// Nothing is charged to the user for a failed edit and the source photo is
  /// untouched, so [retry] can safely restart the run.
  void fail([String? message]) {
    if (state.step != EditFlow.processing) return;
    _stopJob();
    state = state.copyWith(
      step: EditFlow.error,
      clearRun: true,
      failure: message,
    );
  }

  void _beginProcessing() {
    _stopJob();
    state = state.copyWith(
      step: EditFlow.processing,
      progress: 0,
      clearRun: true,
    );

    final photo = state.photo;
    if (photo == null) {
      // Nothing was uploaded, so there is nothing to send: the demo run on the
      // tool's own imagery is all this can honestly be.
      _simulateProcessing();
      return;
    }
    if (!ReplicateConfig.isConfigured) {
      // Names the exact command, because the fix is a relaunch: defines are
      // compile-time, so no amount of retrying inside this build can succeed.
      fail(
        'This build has no Replicate credentials, so it can\'t enhance your '
        'own photos. Relaunch with:\n\n'
        'flutter run --dart-define-from-file=.env',
      );
      return;
    }
    if (!RealEsrgan.supports(state.displayTool)) {
      // Only the enhance tools have a model behind them. The rest keep their
      // place in the catalog, but on a real photo they say so instead of
      // returning demo art as if it were the user's edit.
      fail(
        '${state.displayTool} needs a model this build doesn\'t have yet. '
        'Try ${RealEsrgan.supportedTools.join(', ')}.',
      );
      return;
    }
    _runJob(photo);
  }

  /// The live path: one [EnhanceJob], with the bar easing towards whatever the
  /// current stage allows.
  Future<void> _runJob(File photo) async {
    final job = EnhanceJob(
      photo: photo,
      tool: state.displayTool,
      // The frame chosen on the crop step, or the photo's own for 'Free'.
      aspectRatio: state.cropRatio.value,
    );
    _job = job;
    _startProgressEasing();

    try {
      final outcome = await job.run(onPhase: _onPhase);
      if (!_isCurrent(job)) return;
      _stopProgressTimer();
      state = state.copyWith(
        step: EditFlow.result,
        progress: 100,
        comparePos: 56,
        source: outcome.source,
        result: outcome.result,
        outputLabel: outcome.preset.label,
        phase: EnhancePhase.done,
      );
    } on EnhanceCancelled {
      // The user moved on; `back`/`close` already set the step they wanted.
    } catch (error) {
      if (!_isCurrent(job)) return;
      fail(_messageFor(error));
    } finally {
      if (_job == job) {
        _job = null;
        _stopProgressTimer();
      }
    }
  }

  /// True while [job] is still the run this flow is showing — false once the
  /// user has cancelled, retried or closed, in which case its result is stale
  /// and must not overwrite the newer state.
  bool _isCurrent(EnhanceJob job) =>
      !_disposed && _job == job && state.step == EditFlow.processing;

  void _onPhase(EnhancePhase phase) {
    if (_disposed || state.step != EditFlow.processing) return;
    state = state.copyWith(phase: phase);
  }

  /// Advances the bar towards the ceiling of the current stage.
  ///
  /// The model reports no percentage, so this is openly an ease rather than a
  /// measurement: it slows as it approaches each stage's limit and only jumps
  /// when the job genuinely moves on, which keeps it from claiming 90% while
  /// still uploading.
  void _startProgressEasing() {
    _timer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (_disposed || state.step != EditFlow.processing) return;
      final ceiling = (state.phase ?? EnhancePhase.preparing).progressCeiling;
      final next = state.progress + (ceiling - state.progress) * 0.06;
      if (next > state.progress) {
        state = state.copyWith(progress: min(next, ceiling));
      }
    });
  }

  /// The prototype pipeline, used when there is no photo or no API token.
  void _simulateProcessing() {
    _timer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      final next = min(100.0, state.progress + (5 + _rand.nextDouble() * 9));
      state = state.copyWith(progress: next);
      if (next >= 100) {
        _stopProgressTimer();
        Timer(const Duration(milliseconds: 420), () {
          if (!_disposed && state.step == EditFlow.processing) {
            state = state.copyWith(step: EditFlow.result);
          }
        });
      }
    });
  }

  static String _messageFor(Object error) {
    if (error is ReplicateException) return error.message;
    if (error is StateError) return error.message;
    return 'Something went wrong while enhancing this photo.';
  }

  /// Stops the progress timer and abandons any running prediction.
  void _stopJob() {
    _stopProgressTimer();
    final job = _job;
    _job = null;
    // Fire-and-forget: the cancel round-trip must not hold up the UI, and its
    // failure changes nothing here.
    unawaited(job?.cancel() ?? Future<void>.value());
  }

  void _stopProgressTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

final flowProvider = NotifierProvider<FlowController, FlowState>(
  FlowController.new,
);

/// User preferences.
///
/// Only the export size lives here, and it is chosen where it applies — on the
/// result step, next to the image it will be written at. The Cloud Backup and
/// Notifications switches that used to sit in Settings are gone: neither had a
/// backend or a permission prompt behind it, so both were toggles that changed
/// nothing but their own colour.
@immutable
class AppSettings {
  final String exportQuality; // 'HD' | '2K' | '4K' | '8K'

  const AppSettings({this.exportQuality = '8K'});

  static const List<String> qualities = ['HD', '2K', '4K', '8K'];

  AppSettings copyWith({String? exportQuality}) {
    return AppSettings(exportQuality: exportQuality ?? this.exportQuality);
  }
}

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setExportQuality(String quality) =>
      state = state.copyWith(exportQuality: quality);
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

/// The user's completed edits, newest first. Starts empty — the History
/// screen shows its empty state until the edit flow and the generator append
/// real edits here.
class HistoryController extends Notifier<List<HistoryEntry>> {
  int _nextId = 100;

  @override
  List<HistoryEntry> build() => const [];

  void remove(int id) => state = state.where((e) => e.id != id).toList();

  /// Puts a removed entry back where it was.
  ///
  /// Backs the undo offered when an edit is deleted: the list is ordered
  /// newest-first, so restoring at the original index returns the entry to its
  /// day group rather than dropping it at the top as if it were new. An index
  /// past the end (or a duplicate id) is ignored rather than throwing, since
  /// the list may have changed before undo was tapped.
  void restore(HistoryEntry entry, int index) {
    if (state.any((e) => e.id == entry.id)) return;
    final next = [...state];
    next.insert(index.clamp(0, next.length), entry);
    state = next;
  }

  void add({
    required String tool,
    required String badge,
    required DemoScene scene,
    int seed = 7,
    String? art,
    String? sourcePath,
    String? resultPath,
  }) {
    state = [
      HistoryEntry(
        id: _nextId++,
        tool: tool,
        time: DateTime.now(),
        badge: badge,
        scene: scene,
        seed: seed,
        art: art,
        sourcePath: sourcePath,
        resultPath: resultPath,
      ),
      ...state,
    ];
  }
}

final historyProvider = NotifierProvider<HistoryController, List<HistoryEntry>>(
  HistoryController.new,
);

/// The user's Pro entitlement, plus the in-flight flag Settings' Restore row
/// uses to lock itself and show progress.
///
/// There is no `purchasing` flag and no `managementUrl` any more: buying and
/// subscription management both happen inside RevenueCat's own UI, which owns
/// its progress states and its deep link to Play/App Store. This type now only
/// tracks what the app itself still does — restoring, and knowing whether the
/// user is Pro.
@immutable
class Entitlement {
  final bool isPro;
  final bool restoring;

  const Entitlement({this.isPro = false, this.restoring = false});

  Entitlement copyWith({bool? isPro, bool? restoring}) {
    return Entitlement(
      isPro: isPro ?? this.isPro,
      restoring: restoring ?? this.restoring,
    );
  }
}

/// Outcome of a purchase or restore attempt, surfaced to the UI for messaging.
///
/// Only restore has outcomes to report now — a purchase is made and reported
/// inside RevenueCat's own paywall, which never routes back through here.
enum PurchaseOutcome { success, noneFound, busy, failed }

/// Owns the Pro entitlement — backed by RevenueCat, which is itself the
/// system of record for the purchase (Play Billing underneath it), not a
/// value this app stores and trusts on its own. There is
/// deliberately no local cache of `isPro` written by this app: on every
/// launch, and on every change RevenueCat's backend detects — a renewal, an
/// expiry, a cancellation, a refund, a purchase made on another device — the
/// [CustomerInfo] listener registered in [_bootstrap] is what updates
/// [state], so Pro status can never drift from what was actually bought.
class EntitlementController extends Notifier<Entitlement> {
  bool _disposed = false;
  void Function(CustomerInfo)? _listener;

  @override
  Entitlement build() {
    ref.onDispose(() {
      _disposed = true;
      final listener = _listener;
      if (listener != null) {
        RevenueCatService.removeCustomerInfoListener(listener);
      }
    });
    _bootstrap();
    return const Entitlement();
  }

  /// Configures RevenueCat, subscribes to future entitlement changes, then
  /// reads whatever it already knows. Subscribing first means a change that
  /// lands between "configured" and "first read" is never missed.
  Future<void> _bootstrap() async {
    await RevenueCatService.ensureConfigured();
    if (_disposed) return;

    void onUpdate(CustomerInfo info) {
      if (_disposed) return;
      state = state.copyWith(isPro: RevenueCatService.isPro(info));
    }

    _listener = onUpdate;
    RevenueCatService.addCustomerInfoListener(onUpdate);

    try {
      final info = await RevenueCatService.getCustomerInfo();
      if (!_disposed) onUpdate(info);
    } catch (_) {
      // No CustomerInfo available yet — most commonly because this build has
      // no RevenueCat key for its mode. State stays at its not-Pro default;
      // the listener above still fires if that changes.
    }
  }

  /// Restore Purchases — asks RevenueCat to re-link whatever this store
  /// account has already bought, for a reinstall or a new device.
  ///
  /// The only purchase-path method left here. Buying goes through
  /// RevenueCat's paywall (`lib/widgets/paywall.dart`), which reports its own
  /// result and reaches [state] through the `CustomerInfo` listener above
  /// rather than through this controller.
  Future<PurchaseOutcome> restore() async {
    if (state.restoring) return PurchaseOutcome.busy;

    state = state.copyWith(restoring: true);
    try {
      final info = await RevenueCatService.restorePurchases();
      final isPro = RevenueCatService.isPro(info);
      if (!_disposed) {
        state = state.copyWith(isPro: isPro, restoring: false);
      }
      return isPro ? PurchaseOutcome.success : PurchaseOutcome.noneFound;
    } catch (_) {
      if (!_disposed) state = state.copyWith(restoring: false);
      return PurchaseOutcome.failed;
    }
  }
}

final entitlementProvider = NotifierProvider<EntitlementController, Entitlement>(
  EntitlementController.new,
);

/// Whether the persistent bottom nav should show (hidden in the edit flow).
///
/// The paywall no longer figures here: RevenueCat presents its own as a native
/// modal over the app rather than as one of this app's screens, so there is no
/// longer a route the nav has to hide behind.
final showNavProvider = Provider<bool>((ref) {
  final flow = ref.watch(flowProvider).step;
  return flow == null;
});
