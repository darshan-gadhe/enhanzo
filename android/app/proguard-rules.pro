# R8 / ProGuard rules for the release build.
#
# Meta Audience Network's SDK is annotated with Facebook's internal Infer
# nullability annotations, but does not ship them. R8 treats those dangling
# references as an error and fails `minifyReleaseWithR8` with:
#
#   Missing class com.facebook.infer.annotation.Nullsafe$Mode
#   (referenced from: com.facebook.ads.AbstractAdListener and 28 others)
#
# They are compile-time only and have no effect at runtime, so telling R8 not
# to warn about them is the documented fix rather than a workaround.
-dontwarn com.facebook.infer.annotation.**
-dontwarn com.facebook.ads.internal.**

# The Audience Network SDK resolves ad renderers and listeners reflectively;
# letting R8 rename or strip them makes ads fail to load in release only —
# which is the worst possible place to find out.
-keep class com.facebook.ads.** { *; }
-keep interface com.facebook.ads.** { *; }
