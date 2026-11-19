# ML Kit text recognition: the Flutter plugin refers to the Chinese, Devanagari, Japanese and Korean
# recognizers, which are optional and not bundled (Lantern only uses Latin). Let R8 ignore them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
