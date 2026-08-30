import 'dart:io';


import '../edits_store.dart';
import '../image_ops.dart';
import 'model_errors.dart';
import 'real_esrgan.dart';
import 'replicate_client.dart';

/// The stages one enhance run passes through, in order.
///
/// The processing screen reports these instead of inventing stage names: each
/// value corresponds to a step that genuinely happens.
enum EnhancePhase {
  preparing,
  uploading,
  queued,
  processing,
  downloading,
  done;

  /// Line shown under the tool name while this stage runs.
  String get label => switch (this) {
    EnhancePhase.preparing => 'Preparing your photo',
    EnhancePhase.uploading => 'Uploading your photo',
    EnhancePhase.queued => 'Waiting for the model',
    EnhancePhase.processing => 'Enhancing your photo',
    EnhancePhase.downloading => 'Downloading the result',
    EnhancePhase.done => 'Finishing up',
  };

  /// How far the progress bar may travel while this stage is the current one.
  ///
  /// Real-ESRGAN reports no percentage, so the bar eases towards the ceiling of
  /// the stage the job is *actually* in rather than pretending to measure the
  /// render. Only [done] reaches 100.
  double get progressCeiling => switch (this) {
    EnhancePhase.preparing => 8,
    EnhancePhase.uploading => 24,
    EnhancePhase.queued => 38,
    EnhancePhase.processing => 88,
    EnhancePhase.downloading => 97,
    EnhancePhase.done => 100,
  };
}

/// A finished run: the exact image that was sent, the image that came back, and
/// what was asked of the model.
class EnhanceOutcome {
  /// The cropped, downsized file that was uploaded — the honest "before" for
  /// the comparison slider.
  final File source;

  /// The model's output, saved on the device.
  final File result;

  final RealEsrganPreset preset;
  final String predictionId;

  const EnhanceOutcome({
    required this.source,
    required this.result,
    required this.preset,
    required this.predictionId,
  });
}

/// Raised when a run is abandoned from the UI. Not an error to report.
class EnhanceCancelled implements Exception {
  const EnhanceCancelled();
}

/// One end-to-end enhance: crop → upload → predict → download.
///
/// A job is single-use and owns its own HTTP client, so cancelling one has no
/// effect on any other. [cancel] both stops the local sequence and asks
/// Replicate to stop the prediction, so backing out of the processing screen
/// doesn't leave a paid render running.
class EnhanceJob {
  /// The photo as it came from the picker.
  final File photo;

  /// Catalog tool name, which selects the model preset.
  final String tool;

  /// Frame chosen on the crop step (width ÷ height), or null to keep the
  /// photo's own proportions.
  final double? aspectRatio;

  final ReplicateClient _client;

  bool _cancelled = false;
  String? _predictionId;

  EnhanceJob({
    required this.photo,
    required this.tool,
    required this.aspectRatio,
    ReplicateClient? client,
  }) : _client = client ?? ReplicateClient();

  bool get isCancelled => _cancelled;

  /// Runs the job, reporting each stage as it is entered.
  ///
  /// Throws [EnhanceCancelled] if abandoned, [ReplicateException] for anything
  /// the service reports, and [StateError] if [tool] has no model behind it —
  /// callers check [RealEsrgan.supports] first.
  Future<EnhanceOutcome> run({void Function(EnhancePhase) onPhase = _ignore}) async {
    final preset = RealEsrgan.presetFor(tool);
    if (preset == null) {
      throw StateError('$tool has no model behind it.');
    }

    try {
      onPhase(EnhancePhase.preparing);
      final dir = await EditsStore.directory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      // The one preparation step, for every tool: crop to the chosen frame and
      // fit the result inside the model's GPU budget. Its output is the only
      // thing [ReplicateClient.uploadImage] will accept, so there is no path
      // from here to the network that skips it.
      final prepared = await ImageOps.prepareForUpload(
        photo,
        aspectRatio: aspectRatio,
        targetPathWithoutExtension: '${dir.path}/${stamp}_source',
      );
      final source = prepared.file;
      _throwIfCancelled();

      onPhase(EnhancePhase.uploading);
      final uploaded = await _client.uploadImage(prepared);
      _throwIfCancelled();

      onPhase(EnhancePhase.queued);
      var prediction = await _client.createPrediction(
        version: RealEsrgan.version,
        input: RealEsrgan.inputFor(imageUrl: uploaded, preset: preset),
      );
      _predictionId = prediction.id;
      _throwIfCancelled();

      if (!prediction.isTerminal) {
        onPhase(
          prediction.status == 'processing'
              ? EnhancePhase.processing
              : EnhancePhase.queued,
        );
        prediction = await _client.awaitPrediction(
          prediction.id,
          isCancelled: () => _cancelled,
          onPoll: (p) => onPhase(
            p.status == 'starting'
                ? EnhancePhase.queued
                : EnhancePhase.processing,
          ),
        );
      }
      _throwIfCancelled();

      if (prediction.isCanceled) throw const EnhanceCancelled();
      if (prediction.isFailed) {
        // Never the model's own words. `prediction.error` is written for
        // whoever deployed the model — it has named GPU memory limits and
        // tensor shapes at users — so it is translated here and logged raw
        // only in debug.
        throw ReplicateException(ModelErrors.friendly(prediction.error));
      }
      final outputUrl = prediction.outputUrl;
      if (outputUrl == null) {
        throw const ReplicateException('The model returned no image.');
      }

      onPhase(EnhancePhase.downloading);
      final bytes = await _client.downloadOutput(outputUrl);
      _throwIfCancelled();

      final extension = _extensionOf(outputUrl);
      final result = File('${dir.path}/${prediction.id}.$extension');
      await result.writeAsBytes(bytes, flush: true);

      onPhase(EnhancePhase.done);
      return EnhanceOutcome(
        source: source,
        result: result,
        preset: preset,
        predictionId: prediction.id,
      );
    } finally {
      _client.close();
    }
  }

  /// Abandons the run and stops the prediction server-side if one was started.
  Future<void> cancel() async {
    if (_cancelled) return;
    _cancelled = true;
    final id = _predictionId;
    if (id != null) await _client.cancelPrediction(id);
  }

  void _throwIfCancelled() {
    if (_cancelled) throw const EnhanceCancelled();
  }

  static String _extensionOf(Uri url) {
    final name = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'png';
    final ext = name.substring(dot + 1).toLowerCase();
    return ext.length <= 4 ? ext : 'png';
  }

  static void _ignore(EnhancePhase _) {}
}
