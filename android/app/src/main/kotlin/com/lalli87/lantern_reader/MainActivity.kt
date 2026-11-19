package com.lalli87.lantern_reader

import android.app.Activity
import android.content.Intent
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.min

/**
 * Keeps narration connected to the media service, offers an AAC (.m4a) encoder to Dart, and a file
 * picker that streams the chosen files to the app's cache. (The file_selector plugin reads every
 * picked file into one byte array and sends it over the channel, which runs out of memory on large
 * PDFs such as 80–150 MB magazines.)
 */
class MainActivity : AudioServiceActivity() {
    private var pickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lantern/files").setMethodCallHandler { call, result ->
            when (call.method) {
                "pickFiles" -> {
                    pickResult?.success(null) // a stale request never got an answer
                    pickResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                    }
                    try {
                        startActivityForResult(intent, PICK_FILES)
                    } catch (e: Exception) {
                        pickResult = null
                        result.error("pick", e.message ?: e.toString(), null)
                    }
                }
                // SHA-1 of the certificate this copy of the app is signed with, as Google Cloud shows it
                // (AA:BB:…). Google sign-in only works when an Android OAuth client lists it.
                "signingSha1" -> {
                    try {
                        val pm = packageManager
                        val sigs = if (android.os.Build.VERSION.SDK_INT >= 28) {
                            val info = pm.getPackageInfo(packageName, android.content.pm.PackageManager.GET_SIGNING_CERTIFICATES)
                            val si = info.signingInfo
                            if (si == null) emptyArray() else if (si.hasMultipleSigners()) si.apkContentsSigners else si.signingCertificateHistory
                        } else {
                            @Suppress("DEPRECATION")
                            pm.getPackageInfo(packageName, android.content.pm.PackageManager.GET_SIGNATURES).signatures ?: emptyArray()
                        }
                        val md = java.security.MessageDigest.getInstance("SHA-1")
                        result.success(sigs.map { sig -> md.digest(sig.toByteArray()).joinToString(":") { b -> "%02X".format(b) } })
                    } catch (e: Exception) {
                        result.error("sha1", e.message ?: e.toString(), null)
                    }
                }
                "packageName" -> result.success(packageName)
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lantern/audio").setMethodCallHandler { call, result ->
            when (call.method) {
                "wavToM4a" -> {
                    val wav = call.argument<String>("wav")!!
                    val out = call.argument<String>("out")!!
                    val bitrate = call.argument<Int>("bitrate") ?: 64000
                    val main = Handler(Looper.getMainLooper())
                    Thread {
                        try {
                            AacEncoder.encode(wav, out, bitrate)
                            main.post { result.success(out) }
                        } catch (e: Exception) {
                            File(out).delete()
                            main.post { result.error("encode", e.message ?: e.toString(), null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != PICK_FILES) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pickResult ?: return
        pickResult = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<Map<String, Any>>())
            return
        }
        val uris = mutableListOf<android.net.Uri>()
        data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri) }
        if (uris.isEmpty()) data.data?.let { uris.add(it) }
        val main = Handler(Looper.getMainLooper())
        Thread {
            val dir = File(cacheDir, "imports").apply { mkdirs() }
            val out = mutableListOf<Map<String, Any>>()
            for ((i, uri) in uris.withIndex()) {
                var name = "file$i"
                try {
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                        if (c.moveToFirst() && !c.isNull(0)) name = c.getString(0)
                    }
                    val safe = name.replace(Regex("[/\\\\:*?\"<>|]"), "_")
                    val target = File(dir, "${System.nanoTime()}_$safe")
                    val stream = contentResolver.openInputStream(uri) ?: throw IllegalStateException("no stream")
                    stream.use { input -> target.outputStream().use { input.copyTo(it, 256 * 1024) } }
                    out.add(mapOf("path" to target.absolutePath, "name" to name, "size" to target.length()))
                } catch (e: Exception) {
                    out.add(mapOf("path" to "", "name" to name, "size" to 0L, "error" to (e.message ?: e.toString())))
                }
            }
            main.post { result.success(out) }
        }.start()
    }

    companion object {
        private const val PICK_FILES = 4711
    }
}

/** Encodes a 16-bit PCM WAV file into AAC-LC inside an MP4 (.m4a) container. */
object AacEncoder {
    fun encode(wavPath: String, outPath: String, bitrate: Int) {
        RandomAccessFile(wavPath, "r").use { raf ->
            // Walk the RIFF chunks to find the format and the audio data.
            val head = ByteArray(12)
            raf.readFully(head)
            if (String(head, 0, 4) != "RIFF" || String(head, 8, 4) != "WAVE") throw IllegalArgumentException("Not a WAV file")
            var sampleRate = 22050
            var channels = 1
            var bits = 16
            var dataStart = -1L
            var dataLen = 0L
            val ch = ByteArray(8)
            while (raf.filePointer + 8 <= raf.length()) {
                raf.readFully(ch)
                val id = String(ch, 0, 4)
                var size = ByteBuffer.wrap(ch, 4, 4).order(ByteOrder.LITTLE_ENDIAN).int.toLong() and 0xFFFFFFFFL
                val body = raf.filePointer
                if (id == "fmt ") {
                    val f = ByteArray(16)
                    raf.readFully(f)
                    val bb = ByteBuffer.wrap(f).order(ByteOrder.LITTLE_ENDIAN)
                    channels = bb.getShort(2).toInt()
                    sampleRate = bb.getInt(4)
                    bits = bb.getShort(14).toInt()
                } else if (id == "data") {
                    if (size == 0L || body + size > raf.length()) size = raf.length() - body
                    dataStart = body
                    dataLen = size
                    break
                }
                raf.seek(body + size + (size and 1L))
            }
            if (dataStart < 0) throw IllegalArgumentException("WAV has no audio data")
            if (bits != 16) throw IllegalArgumentException("Only 16-bit audio is supported")
            raf.seek(dataStart)
            val dataEnd = dataStart + dataLen

            val format = MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, channels)
            format.setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            format.setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 32768)
            val codec = MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
            val muxer = MediaMuxer(outPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var track = -1
            var muxing = false
            val info = MediaCodec.BufferInfo()
            val frameBytes = channels * 2
            val buf = ByteArray(32768)
            var readTotal = 0L
            var inputDone = false
            var outputDone = false
            try {
                while (!outputDone) {
                    if (!inputDone) {
                        val i = codec.dequeueInputBuffer(10_000)
                        if (i >= 0) {
                            val ib = codec.getInputBuffer(i)!!
                            ib.clear()
                            var want = min(ib.remaining(), buf.size)
                            want -= want % frameBytes
                            val left = dataEnd - raf.filePointer
                            val n = if (left <= 0) -1 else raf.read(buf, 0, min(want.toLong(), left).toInt())
                            val pts = readTotal * 1_000_000L / (sampleRate.toLong() * frameBytes)
                            if (n <= 0) {
                                codec.queueInputBuffer(i, 0, 0, pts, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                                inputDone = true
                            } else {
                                ib.put(buf, 0, n)
                                codec.queueInputBuffer(i, 0, n, pts, 0)
                                readTotal += n
                            }
                        }
                    }
                    val o = codec.dequeueOutputBuffer(info, 10_000)
                    if (o == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                        track = muxer.addTrack(codec.outputFormat)
                        muxer.start()
                        muxing = true
                    } else if (o >= 0) {
                        val ob = codec.getOutputBuffer(o)!!
                        if (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0) info.size = 0
                        if (info.size > 0 && muxing) {
                            ob.position(info.offset)
                            ob.limit(info.offset + info.size)
                            muxer.writeSampleData(track, ob, info)
                        }
                        codec.releaseOutputBuffer(o, false)
                        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                    }
                }
            } finally {
                codec.stop()
                codec.release()
                if (muxing) muxer.stop()
                muxer.release()
            }
        }
    }
}
