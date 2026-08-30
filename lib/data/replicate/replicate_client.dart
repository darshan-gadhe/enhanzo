import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../image_ops.dart';
import 'device_id.dart';
import 'model_errors.dart';
import 'replicate_config.dart';

/// A failed call to Replicate, carrying a message fit to show a user.
///
/// The API's own `detail` string is preferred when it sends one — it names the
/// real problem ("Insufficient credit", "Invalid token") far better than a bare
/// status code can.
class ReplicateException implements Exception {
  final String message;
  final int? statusCode;

  const ReplicateException(this.message, {this.statusCode});

  @override
  String toString() => 'ReplicateException($statusCode): $message';
}

/// One prediction as the API reports it.
class Prediction {
  final String id;

  /// `starting` | `processing` | `succeeded` | `failed` | `canceled`.
  final String status;

  /// Model output. Real-ESRGAN returns a single URL string; other models return
  /// a list, so both shapes are accepted and normalised by [outputUrl].
  final Object? output;

  /// The model's own error text on a failed run.
  final String? error;

  const Prediction({
    required this.id,
    required this.status,
    this.output,
    this.error,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      id: (json['id'] ?? '') as String,
      status: (json['status'] ?? 'starting') as String,
      output: json['output'],
      error: json['error'] as String?,
    );
  }

  bool get isSucceeded => status == 'succeeded';
  bool get isFailed => status == 'failed';
  bool get isCanceled => status == 'canceled';

  /// True once the run has stopped moving, whatever the outcome — the poll
  /// loop's exit condition.
  bool get isTerminal => isSucceeded || isFailed || isCanceled;

  /// The single image this prediction produced, or null if it produced none.
  Uri? get outputUrl {
    final value = output;
    if (value is String && value.isNotEmpty) return Uri.tryParse(value);
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String && first.isNotEmpty) return Uri.tryParse(first);
    }
    return null;
  }
}

/// Thin client over the Replicate HTTP API — the four calls this app makes:
/// upload a file, create a prediction, read it back, cancel it.
///
/// It holds no model knowledge; see `real_esrgan.dart` for the version and
/// inputs, and `enhance_job.dart` for the sequence they're used in.
class ReplicateClient {
  final http.Client _http;
  final bool _ownsClient;

  ReplicateClient({http.Client? httpClient})
    : _http = httpClient ?? http.Client(),
      _ownsClient = httpClient == null;

  /// How long the server is asked to hold the create request open before
  /// answering. A short run then needs no polling at all; a long one comes back
  /// still `processing` and [awaitPrediction] takes over.
  static const Duration _serverWait = Duration(seconds: 55);

  /// Gap between polls once the initial wait has expired.
  static const Duration pollInterval = Duration(milliseconds: 1500);

  /// Ceiling on a single request, generous enough to cover [_serverWait].
  static const Duration _requestTimeout = Duration(seconds: 90);

  /// Headers common to every JSON request.
  ///
  /// * **Direct mode** — attaches the Replicate token itself.
  /// * **Proxy mode** — attaches the app key and this install's id instead,
  ///   which is what the Cloudflare proxy checks; see
  ///   `cloudflare/replicate-proxy/src/auth.ts`. No Replicate token exists in
  ///   this build to send.
  Future<Map<String, String>> _headers() async {
    final proxyHeaders = ReplicateConfig.usesProxy
        ? await _proxyHeaders()
        : const <String, String>{};
    return {
      if (ReplicateConfig.sendsToken)
        'Authorization': 'Bearer ${ReplicateConfig.apiToken}',
      ...proxyHeaders,
      'Content-Type': 'application/json',
    };
  }

  Future<Map<String, String>> _proxyHeaders() async {
    return {
      'X-App-Key': ReplicateConfig.appKey,
      'X-Device-Id': await DeviceId.get(),
    };
  }

  /// Uploads [image] and returns the URL a model input can be pointed at.
  ///
  /// Predictions take image inputs as URLs, and a photo on a phone has none.
  /// Replicate's Files API is the supported way across that gap — better than
  /// inlining a multi-megabyte photo as a base64 data URI on every run.
  ///
  /// Takes a [PreparedImage] rather than a [File] on purpose. This is the one
  /// place in the app where image bytes leave the device, and a `File`
  /// parameter would accept anything — the picked photo at full resolution, a
  /// preview, a half-finished temp file. Requiring the type that only
  /// [ImageOps.prepareForUpload] can produce makes "the uploaded file is the
  /// prepared file" a fact about what compiles, not a rule someone has to keep
  /// in mind at each new call site.
  Future<Uri> uploadImage(PreparedImage image) async {
    // The budget is re-checked against the payload's own measurements rather
    // than trusted from earlier in the call: this is the last point before the
    // bytes go out.
    if (!image.isWithinBudget) {
      throw const ReplicateException(
        "This photo couldn't be prepared for enhancement. "
        'Please try another image.',
      );
    }

    final file = image.file;
    final request = http.MultipartRequest(
      'POST',
      ReplicateConfig.endpoint('/v1/files'),
    );
    if (ReplicateConfig.sendsToken) {
      request.headers['Authorization'] = 'Bearer ${ReplicateConfig.apiToken}';
    }
    if (ReplicateConfig.usesProxy) {
      request.headers.addAll(await _proxyHeaders());
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'content',
        file.path,
        contentType: _mediaTypeFor(file.path),
      ),
    );

    final streamed = await _send(() => _http.send(request));
    final response = await http.Response.fromStream(streamed);
    final json = _decode(response);

    // The `get` URL is the one predictions are meant to consume.
    final urls = json['urls'];
    final url = urls is Map<String, dynamic> ? urls['get'] as String? : null;
    final parsed = url == null ? null : Uri.tryParse(url);
    if (parsed == null) {
      throw const ReplicateException('The upload returned no usable file URL.');
    }
    return parsed;
  }

  /// Starts a run of [version] with [input], waiting briefly for it to finish
  /// before returning whatever state it has reached.
  Future<Prediction> createPrediction({
    required String version,
    required Map<String, Object?> input,
  }) async {
    final headers = await _headers();
    final response = await _send(
      () => _http.post(
        ReplicateConfig.endpoint('/v1/predictions'),
        headers: {
          ...headers,
          // Hold the connection open rather than returning `starting`
          // immediately: most enhance runs finish inside this window.
          'Prefer': 'wait=${_serverWait.inSeconds}',
        },
        body: jsonEncode({'version': version, 'input': input}),
      ),
    );
    return Prediction.fromJson(_decode(response));
  }

  Future<Prediction> getPrediction(String id) async {
    final headers = await _headers();
    final response = await _send(
      () => _http.get(
        ReplicateConfig.endpoint('/v1/predictions/$id'),
        headers: headers,
      ),
    );
    return Prediction.fromJson(_decode(response));
  }

  /// Asks the server to stop a run. Best-effort: a prediction that has already
  /// finished can't be cancelled, and that is not worth surfacing.
  Future<void> cancelPrediction(String id) async {
    try {
      final headers = await _headers();
      await _http
          .post(
            ReplicateConfig.endpoint('/v1/predictions/$id/cancel'),
            headers: headers,
          )
          .timeout(_requestTimeout);
    } catch (_) {
      // Ignored on purpose — see above.
    }
  }

  /// Polls [id] until it stops moving.
  ///
  /// [onPoll] fires after each read so a caller can report progress, and
  /// [isCancelled] is checked between polls so an abandoned job stops costing
  /// requests the moment the user backs out.
  Future<Prediction> awaitPrediction(
    String id, {
    Duration timeout = const Duration(minutes: 5),
    void Function(Prediction)? onPoll,
    bool Function()? isCancelled,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (true) {
      if (isCancelled?.call() ?? false) {
        throw const ReplicateException('Cancelled.');
      }
      if (DateTime.now().isAfter(deadline)) {
        throw const ReplicateException(
          'The model took too long to respond. Please try again.',
        );
      }
      await Future<void>.delayed(pollInterval);
      if (isCancelled?.call() ?? false) {
        throw const ReplicateException('Cancelled.');
      }
      final prediction = await getPrediction(id);
      onPoll?.call(prediction);
      if (prediction.isTerminal) return prediction;
    }
  }

  /// Fetches the produced image. The delivery URL is a plain signed link, so it
  /// takes no auth header.
  Future<Uint8List> downloadOutput(Uri url) async {
    final response = await _send(() => _http.get(url));
    if (response.statusCode >= 400) {
      throw ReplicateException(
        'The finished image could not be downloaded.',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }

  void close() {
    if (_ownsClient) _http.close();
  }

  /// Runs one request, turning transport failures into a [ReplicateException]
  /// the UI can put on screen.
  Future<T> _send<T>(Future<T> Function() request) async {
    try {
      return await request().timeout(_requestTimeout);
    } on ReplicateException {
      rethrow;
    } on SocketException {
      throw const ReplicateException(
        "Couldn't reach the server. Check your connection and try again.",
      );
    } catch (error) {
      if (error is http.ClientException) {
        throw ReplicateException(error.message);
      }
      throw const ReplicateException(
        'The request failed. Please try again.',
      );
    }
  }

  /// Parses a JSON body, preferring the API's own error text when it fails.
  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? json;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        json = null;
      }
    }

    if (response.statusCode >= 400) {
      // The API's own `detail` names the real problem far better than a status
      // code can, but it is written for a developer — so it is translated
      // rather than shown. [ModelErrors] keeps the raw text in the debug log.
      final detail = json?['detail'] ?? json?['title'];
      throw ReplicateException(
        ModelErrors.friendly(detail is String ? detail : null),
        statusCode: response.statusCode,
      );
    }
    if (json == null) {
      throw const ReplicateException('The server returned an unreadable reply.');
    }
    return json;
  }

  /// Content type for an upload, from the file's extension. Replicate stores
  /// what we declare, so an honest type keeps the served URL usable by the
  /// model.
  static MediaType _mediaTypeFor(String path) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => MediaType('image', 'png'),
      'webp' => MediaType('image', 'webp'),
      'heic' || 'heif' => MediaType('image', 'heic'),
      _ => MediaType('image', 'jpeg'),
    };
  }
}
