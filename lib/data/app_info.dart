/// Facts about the app itself — the strings Settings, the paywall and the OS
/// share sheet all quote.
///
/// Centralised so the version, the support address, the link and the Pro
/// claims can't drift apart between the two screens that show them. Anything
/// user-facing that describes *the product* belongs here rather than inline in
/// a widget.
class AppInfo {
  AppInfo._();

  static const String name = 'Enhanzo: AI Photo Enhancer';
  static const String shortName = 'Enhanzo';
  static const String version = '1.0.0';

  static const String supportEmail = 'itechcoderdev@gmail.com';

  /// Play Store package name — the one identifier the store links are built
  /// from, so a rename can't leave half of them pointing at the old app.
  static const String packageName = 'com.techneoo.ai.photo.enhancer';

  /// The Play listing. Where Share App points, and what Rate opens.
  static const String link =
      'https://play.google.com/store/apps/details?id=$packageName';

  /// Deep link straight into the Play review sheet. Falls back to the normal
  /// listing on any device without Play (see Settings › Rate), so this is
  /// never a dead button.
  static const String reviewLink = '$link&showAllReviews=true';

  /// Message handed to the OS share sheet by Settings › Share App.
  static const String shareMessage =
      '$shortName — enhance, restore and restyle photos on your phone. $link';

  /// What a Pro subscription actually includes. The paywall and the Settings
  /// upgrade card read from this list, so neither can advertise something the
  /// other doesn't.
  static const List<String> proBenefits = [
    'Every AI tool unlocked',
    'Exports up to 8K',
    'No ads, no watermarks',
  ];
}
