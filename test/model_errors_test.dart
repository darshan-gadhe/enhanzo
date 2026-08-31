// What a user is allowed to read when a run fails.
//
// Every message the error screen can show for a failed edit comes from
// [ModelErrors]. These pin that the model's own wording never survives the
// trip, including the exact string that reached a user's screen in production.

import 'package:ai_enhancer/data/replicate/model_errors.dart';
import 'package:flutter_test/flutter_test.dart';

/// The live failure, verbatim.
const _reported =
    'Input image of dimensions (1536, 1536, 4) has a total number of pixels '
    '2359296 greater than the max size that fits in GPU memory on this '
    'hardware, 2096704. Resize input image and try again.';

/// Vocabulary that belongs in a log, never on a screen.
const _jargon = [
  'gpu',
  'cuda',
  'tensor',
  'dimensions',
  'pixels',
  '2359296',
  '2096704',
  'nvidia',
  'traceback',
  'stack',
  'null',
  'exception',
];

void main() {
  test('the reported failure is translated into something actionable', () {
    expect(ModelErrors.friendly(_reported), ModelErrors.tooLarge);
  });

  group('no message leaks the machine', () {
    const raws = <String>[
      _reported,
      'CUDA out of memory. Tried to allocate 2.00 GiB',
      'RuntimeError: Expected all tensors to be on the same device',
      'Traceback (most recent call last): NullPointerException',
      'You have insufficient credit.',
      'Daily limit reached',
      'prediction timed out after 300s',
      'cannot identify image file',
      '',
    ];

    for (final raw in raws) {
      test('"${raw.isEmpty ? '(empty)' : raw.substring(0, raw.length.clamp(0, 40))}"',
          () {
        final message = ModelErrors.friendly(raw).toLowerCase();
        for (final word in _jargon) {
          expect(message, isNot(contains(word)), reason: 'leaked "$word"');
        }
        expect(message, isNotEmpty);
        // A sentence, not a code.
        expect(message.trim(), endsWith('.'));
      });
    }
  });

  group('causes worth telling apart', () {
    test('a size rejection, however it is phrased', () {
      for (final raw in const [
        'total number of pixels 2359296 greater than the max size',
        'the image does not fit in GPU memory on this hardware',
        'Resize input image and try again',
        'CUDA error: out of memory',
      ]) {
        expect(ModelErrors.friendly(raw), ModelErrors.tooLarge, reason: raw);
      }
    });

    test('an account problem is not blamed on the photo', () {
      final message = ModelErrors.friendly('You have insufficient credit.');
      expect(message, isNot(ModelErrors.tooLarge));
      expect(message.toLowerCase(), contains('temporarily unavailable'));
    });

    test('a quota is described as a limit the user can wait out', () {
      expect(ModelErrors.friendly('Daily limit reached').toLowerCase(),
          contains('limit'));
      expect(ModelErrors.friendly('429 too many requests').toLowerCase(),
          contains('limit'));
    });

    test('a timeout invites a retry', () {
      expect(ModelErrors.friendly('the request timed out').toLowerCase(),
          contains('again'));
    });

    test('an unreadable file points at the photo, not the service', () {
      expect(ModelErrors.friendly('cannot identify image file').toLowerCase(),
          contains('another image'));
    });

    test('a safety-checker refusal does not advise a pointless retry', () {
      // "Try again" is wrong advice: the same photo and prompt will be
      // refused again. Found when Stable Diffusion's checker rejected an
      // abstract test image.
      final message = ModelErrors.friendly('NSFW content detected. Try '
          'running it again, or try a different prompt.');
      expect(message, ModelErrors.blocked);
      expect(message.toLowerCase(), contains('different'));
    });

    test('anything unrecognised falls back to an honest generic', () {
      final message = ModelErrors.friendly('E_UNKNOWN_47');
      expect(message, isNot(contains('E_UNKNOWN_47')));
      expect(message.toLowerCase(), contains('try again'));
    });

    test('null is a failure with no reason, not a crash', () {
      expect(ModelErrors.friendly(null), isNotEmpty);
    });
  });
}
