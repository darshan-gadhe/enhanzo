package com.techneoo.ai.photo.enhancer

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.facebook.ads.Ad
import com.facebook.ads.AdError
import com.facebook.ads.RewardedInterstitialAd
import com.facebook.ads.RewardedInterstitialAdListener
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges Meta Audience Network's **rewarded interstitial** format.
 *
 * The `easy_audience_network` plugin only wraps `RewardedVideoAd`. Rewarded
 * video and rewarded interstitial are distinct placement types in Meta's
 * dashboard, and loading one through the other's API fails with a placement
 * mismatch — so this app's rewarded placement, which is a rewarded
 * interstitial, needs its own binding.
 *
 * The channel is deliberately one shot: Dart calls `show` once and gets a
 * single string back, rather than a stream of callbacks to reassemble on the
 * other side. That keeps the "was the reward actually earned?" decision in
 * one place and makes it impossible to report a reward for an ad that was
 * merely opened.
 *
 * Results:
 *  - `earned`      — the user watched it through; [onRewardedInterstitialCompleted] fired
 *  - `dismissed`   — closed early, no reward
 *  - `unavailable` — no fill, no network, or the ad could not be shown
 */
class MetaRewardedInterstitial(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL).apply {
        setMethodCallHandler(this@MetaRewardedInterstitial)
    }

    /** One attempt at a time; a second call while busy reports unavailable. */
    private var inFlight = false

    private val handler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "show" -> {
                val placementId = call.argument<String>("placementId")
                if (placementId.isNullOrEmpty()) {
                    result.success(UNAVAILABLE)
                    return
                }
                show(placementId, result)
            }
            else -> result.notImplemented()
        }
    }

    private fun show(placementId: String, result: MethodChannel.Result) {
        if (inFlight) {
            result.success(UNAVAILABLE)
            return
        }
        inFlight = true

        val ad = RewardedInterstitialAd(activity, placementId)
        var earned = false
        // MethodChannel.Result must be answered exactly once — Meta can fire
        // both a completion and a close, and an error can arrive after either.
        var answered = false
        var loadTimeout: Runnable? = null

        fun finish(outcome: String) {
            if (answered) return
            answered = true
            inFlight = false
            loadTimeout?.let { handler.removeCallbacks(it) }
            result.success(outcome)
            // Meta requires an explicit destroy to release the native ad;
            // skipping it leaks and can break the next load.
            runCatching { ad.destroy() }
        }

        // Backstop for a load that never reports anything at all — which is
        // what happens if the SDK failed to initialize (no network at launch,
        // say). Without it no callback ever fires, `inFlight` never clears,
        // the Dart side never gets a result, and the ad gate spins forever
        // with no way out. Covers loading only: it is cancelled once the ad is
        // on screen, because a user watching an ad legitimately takes time.
        loadTimeout = Runnable { finish(UNAVAILABLE) }
        handler.postDelayed(loadTimeout, LOAD_TIMEOUT_MS)

        val listener = object : RewardedInterstitialAdListener {
            override fun onError(target: Ad?, error: AdError?) = finish(UNAVAILABLE)

            override fun onAdLoaded(target: Ad?) {
                // show() returns false when the ad is already invalidated.
                if (!ad.show()) {
                    finish(UNAVAILABLE)
                    return
                }
                // It's on screen now; the rest is the user's own pace.
                loadTimeout?.let { handler.removeCallbacks(it) }
            }

            /** The one callback meaning the ad was actually watched through. */
            override fun onRewardedInterstitialCompleted() {
                earned = true
            }

            override fun onRewardedInterstitialClosed() {
                finish(if (earned) EARNED else DISMISSED)
            }

            override fun onAdClicked(target: Ad?) = Unit
            override fun onLoggingImpression(target: Ad?) = Unit
        }

        runCatching {
            ad.loadAd(ad.buildLoadAdConfig().withAdListener(listener).build())
        }.onFailure { finish(UNAVAILABLE) }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    companion object {
        const val CHANNEL = "enhanzo/meta_rewarded_interstitial"

        /** How long a load may take before it is reported as unavailable. */
        private const val LOAD_TIMEOUT_MS = 30_000L
        private const val EARNED = "earned"
        private const val DISMISSED = "dismissed"
        private const val UNAVAILABLE = "unavailable"
    }
}
