/// The app's legal documents, shown in full inside Settings.
///
/// Held in the app rather than linked out, because there is no website behind
/// `enhanzo.app` — a Privacy Policy row that opens a 404 is worse than no row
/// at all, and both Google Play and the subscription stores expect these to be
/// genuinely reachable from inside the product.
///
/// **Play Console separately requires a publicly hosted privacy-policy URL**
/// for the store listing itself, which an in-app copy does not satisfy. The
/// same text is mirrored at `store/privacy-policy.md` and `store/terms-of-use.md`
/// for publishing somewhere public; keep the two in step if either changes.
class Legal {
  Legal._();

  /// Shown in the document header and in the store copies.
  static const String effectiveDate = '01/08/2026';

  static const String privacyPolicy = '''
Effective Date: $effectiveDate

Your privacy matters to us. This policy explains what information we collect when you use AI Photo Enhancer, how we use it, and what choices you have.

1. INFORMATION WE COLLECT

a. Content You Provide
• Uploaded Images — photos you upload for editing or enhancement.
• Generated Images — the output images created by the AI from the photos you upload.

b. Information Collected Automatically
• Advertising Identifiers — our app displays ads. Advertising partners may collect device advertising identifiers (such as Google Advertising ID / IDFA) to show relevant ads and measure ad performance.
• Purchase and Subscription Data — our app offers a premium subscription. Purchases are processed by Google Play Store / Apple App Store. We may receive limited transaction details (such as purchase date, product ID, and subscription status) to activate your premium features. We never collect or store your card, bank, or payment credentials — these are handled entirely by Google/Apple.

Note: Our app does not require you to create an account or log in, so we do not collect your name, email, or login credentials.

2. HOW WE USE YOUR INFORMATION

• To Provide the Service: We use your images to generate your enhanced/output images.
• To Show Ads: We work with advertising partners to display ads within the app, which may be personalized based on your advertising identifier and app usage.
• To Manage Your Premium Subscription: We use purchase data to verify your subscription and unlock premium features.
• We Do Not Train Models On Your Content: Your photos are sent to third-party AI providers solely to produce your result. We do not use your images to train or improve any AI model of our own.

3. HOW WE SHARE YOUR INFORMATION

We do not sell your personal information. We only share it in these ways:

• Third-Party AI Providers: To generate images, your images are sent to third-party AI service providers.
• Advertising Partners: Ad network partners may receive your advertising identifier to serve and measure ads.
• App Store Platforms: Google Play Store / Apple App Store process your subscription payments and share limited purchase confirmation data with us.
• Legal Requirements: We may disclose information if required by law or a valid request from a public authority.

4. DATA RETENTION AND SECURITY

Generated images are typically stored for about 30 days for your convenience, after which they may be automatically deleted. You can also delete them manually anytime within the app.

We use reasonable security measures to protect your data, though no method of transmission over the internet is 100% secure.

5. YOUR RIGHTS AND CHOICES

• Delete Your Content: Delete uploaded or generated images directly within the app at any time.
• Manage Ad Personalization: You can limit interest-based ads through your device's advertising settings (e.g., "Opt out of Ads Personalization" on Android, or "Limit Ad Tracking" on iOS).
• Manage Your Subscription: Subscriptions can be viewed, changed, or cancelled through your Google Play Store / Apple App Store account settings.
• Data Removal Requests: Since the app does not require an account, we hold minimal data tied to you. If you'd like any device- or purchase-linked data removed, contact us using the details below.

6. CHILDREN'S PRIVACY

Our service is not intended for anyone under 13. We do not knowingly collect personal information from children under 13. If we learn that a child under 13 has used the app and provided personal information, we will delete it promptly.

7. CHANGES TO THIS POLICY

We may update this Privacy Policy from time to time. Any changes will be posted on this page. Please review it periodically.

8. CONTACT US

If you have any questions or suggestions, please contact us at: itechcoderdev@gmail.com
''';

  static const String termsOfUse = '''
Effective Date: $effectiveDate

Please read these Terms carefully. By downloading or using AI Photo Enhancer ("the App"), you agree to them. If you do not agree, please do not use the App.

1. THE SERVICE

The App uses artificial intelligence to enhance, restore and edit photos you provide. You do not need an account to use it.

2. YOUR CONTENT

• You keep ownership of the photos you upload and the images the App produces from them.
• You are responsible for the content you upload. You confirm that you have the right to use each photo you upload, and that doing so does not infringe anyone else's rights.
• You agree not to upload content that is illegal, hateful, sexually explicit involving minors, or that violates another person's privacy or intellectual property.
• To produce your result, your photos are sent to third-party AI providers for processing. See our Privacy Policy for details.

3. ACCEPTABLE USE

You agree not to:
• Use the App to create material that is unlawful, harmful, deceptive, or intended to harass or impersonate someone.
• Attempt to reverse engineer, decompile, or interfere with the App or its infrastructure.
• Use automated means to access the service, or abuse it in a way that degrades it for others.

We may limit or suspend access if the App is used in these ways.

4. SUBSCRIPTIONS AND PAYMENT

• The App offers an optional premium subscription. Prices and billing periods are shown in the App before you purchase.
• Payment is charged to your Google Play account at confirmation of purchase.
• Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period.
• You can manage or cancel your subscription in your Google Play account settings. Cancelling stops future renewals; it does not refund the current period.
• If a free trial is offered, any unused portion is forfeited when you purchase a subscription.
• Refunds are handled by Google Play under their policies.

5. ADVERTISING

The free version of the App shows ads, including ads you may choose to watch in exchange for a feature unlock. Watching an ad is always optional, and a premium subscription removes ads.

6. AI OUTPUT

AI results are generated automatically and may not always be accurate, realistic, or suitable for your purpose. The App is provided for personal and creative use, and output should not be relied on where accuracy matters (for example, as evidence or as a factual record).

7. AVAILABILITY

We aim to keep the App working, but we do not guarantee it will be uninterrupted or error-free. Features may change, and processing depends on third-party services that may be unavailable at times.

8. DISCLAIMER AND LIABILITY

The App is provided "as is", without warranties of any kind to the extent permitted by law. To the maximum extent permitted by law, we are not liable for indirect or consequential losses, or for loss of data or images. Nothing in these Terms limits liability that cannot be limited by law.

9. CHANGES TO THESE TERMS

We may update these Terms from time to time. Continued use of the App after an update means you accept the revised Terms.

10. CONTACT

Questions about these Terms: itechcoderdev@gmail.com
''';
}
