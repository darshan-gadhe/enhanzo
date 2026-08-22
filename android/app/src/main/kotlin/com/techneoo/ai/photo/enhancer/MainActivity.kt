package com.techneoo.ai.photo.enhancer

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Hosts the Flutter engine.
 *
 * Extends [FlutterFragmentActivity], not the more usual `FlutterActivity`,
 * because RevenueCat's hosted paywall is native Android UI presented into this
 * activity and needs a `FragmentActivity` to attach to. With a plain
 * `FlutterActivity` the SDK refuses to present and logs
 * "Paywalls require your activity to subclass FlutterFragmentActivity" —
 * the paywall silently never opens.
 */
class MainActivity : FlutterFragmentActivity() {

    private var rewardedInterstitial: MetaRewardedInterstitial? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Meta's rewarded *interstitial* format, which the Flutter plugin
        // doesn't bind — see MetaRewardedInterstitial.
        rewardedInterstitial = MetaRewardedInterstitial(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onDestroy() {
        rewardedInterstitial?.dispose()
        rewardedInterstitial = null
        super.onDestroy()
    }
}
