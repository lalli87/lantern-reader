# ML Kit text recognition: the Flutter plugin refers to the Chinese, Devanagari, Japanese and Korean
# recognizers, which are optional and not bundled (Lantern only uses Latin). Let R8 ignore them.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Comic archive libraries: optional codecs and logging they can use but Lantern doesn't bundle.
-dontwarn com.github.luben.zstd.**
-dontwarn org.brotli.dec.**
-dontwarn org.objectweb.asm.**
-dontwarn org.slf4j.**
-dontwarn org.apache.commons.compress.harmony.**
-dontwarn javax.annotation.**
