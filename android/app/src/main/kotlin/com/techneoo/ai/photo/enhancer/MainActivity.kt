package com.techneoo.ai.photo.enhancer

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Hosts the Flutter engine.
 *
 * Extends [FlutterFragmentActivity], not the more usual `FlutterActivity`,
 * because RevenueCat's hosted paywall is native Android UI presented into this
 * activity and needs a `FragmentActivity` to attach to. With a plain
 * `FlutterActivity` the SDK refuses to present and logs
 * "Paywalls require your activity to subclass FlutterFragmentActivity" —
 * the paywall silently never opens.
 *
 * No ad bridge is registered here any more: interstitials are handled entirely
 * by the `easy_audience_network` plugin. The hand-written channel that used to
 * live alongside this class existed only for Meta's rewarded *interstitial*
 * format, which the plugin doesn't wrap — and rewarded ads are gone.
 */
class MainActivity : FlutterFragmentActivity()
