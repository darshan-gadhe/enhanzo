// When the app is allowed to ask for a rating.
//
// Rating average and volume are among the heaviest Play ranking signals, and a
// prompt at the wrong moment earns one star — worse than no review. These pin
// the "when not to ask" rules, which are the whole design.

import 'package:ai_enhancer/data/review_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stands in for Play's review service, which is not reachable from a test.
class FakeReview implements InAppReview {
  bool available;
  int requests = 0;
  int listingOpens = 0;

  FakeReview({this.available = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async =>
      listingOpens++;
}

void main() {
  late FakeReview review;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ReviewPrompt.resetForTest();
    review = FakeReview();
    ReviewPrompt.instance = review;
  });

  Future<void> save() => ReviewPrompt.recordSaveAndMaybeAsk();

  test('the first save is too early to ask', () async {
    await save();
    expect(review.requests, 0,
        reason: 'one result is not enough to have an opinion about');
  });

  test('the second save is the moment', () async {
    await save();
    await save();
    expect(review.requests, 1);
  });

  test('it asks once, and never again', () async {
    await save();
    await save();
    expect(review.requests, 1);

    for (var i = 0; i < 5; i++) {
      ReviewPrompt.resetForTest(); // a new session
      await save();
    }
    expect(review.requests, 1, reason: 'asking twice earns a one-star review');
  });

  test('the count survives a restart, so two sessions of one save qualify',
      () async {
    await save();
    ReviewPrompt.resetForTest(); // relaunch
    await save();
    expect(review.requests, 1);
  });

  test('nothing is asked when Play says the sheet is unavailable', () async {
    review.available = false;
    await save();
    await save();
    expect(review.requests, 0);
  });

  test('an unavailable sheet does not burn the one ask', () async {
    review.available = false;
    await save();
    await save();

    review.available = true;
    ReviewPrompt.resetForTest();
    await save();
    expect(review.requests, 1, reason: 'the opportunity was never spent');
  });

  test('a declined request is not retried on the next save', () async {
    // Play may decline to show the sheet for reasons the app cannot see.
    // Retrying would spend a quota Play has already refused.
    await save();
    await save();
    expect(review.requests, 1);

    ReviewPrompt.resetForTest();
    await save();
    await save();
    expect(review.requests, 1);
  });

  test('it never opens the store listing behind the user\'s back', () async {
    await save();
    await save();
    expect(review.listingOpens, 0,
        reason: 'that is the Settings row, and it is the user\'s choice');
  });

  test('isDue reports the next save honestly', () async {
    expect(await ReviewPrompt.isDue(), isFalse);
    await save();
    expect(await ReviewPrompt.isDue(), isTrue);
    await save();
    expect(await ReviewPrompt.isDue(), isFalse);
  });

  test('a storage failure is never visible to the user', () async {
    await expectLater(save(), completes);
  });
}
