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
    private var wakeLock: android.os.PowerManager.WakeLock? = null
    private var wifiLock: android.net.wifi.WifiManager.WifiLock? = null

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
                // A folder (such as Download) chosen once; Android remembers the permission to read it.
                "pickFolder" -> {
                    folderResult?.success(null)
                    folderResult = result
                    try {
                        startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE), PICK_FOLDER)
                    } catch (e: Exception) {
                        folderResult = null
                        result.error("folder", e.message ?: e.toString(), null)
                    }
                }
                "listFolder" -> {
                    val tree = android.net.Uri.parse(call.argument<String>("uri")!!)
                    val exts = call.argument<List<String>>("exts")!!.toSet()
                    val main = Handler(Looper.getMainLooper())
                    Thread {
                        try {
                            val out = FolderScan.list(this, tree, exts)
                            main.post { result.success(out) }
                        } catch (e: Exception) {
                            main.post { result.error("list", e.message ?: e.toString(), null) }
                        }
                    }.start()
                }
                "copyUris" -> {
                    val uris = call.argument<List<String>>("uris")!!.map { android.net.Uri.parse(it) }
                    val main = Handler(Looper.getMainLooper())
                    Thread {
                        val out = copyUris(uris)
                        main.post { result.success(out) }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lantern/archive").setMethodCallHandler { call, result ->
            when (call.method) {
                "extract" -> {
                    val src = File(call.argument<String>("path")!!)
                    val out = File(call.argument<String>("out")!!)
                    val main = Handler(Looper.getMainLooper())
                    Thread {
                        try {
                            val n = ArchiveExtractor.extract(src, out)
                            main.post { result.success(n) }
                        } catch (e: Exception) {
                            main.post { result.error("extract", e.message ?: e.toString(), null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
        incoming = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lantern/incoming").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        result.success(ArrayList(pendingIncoming))
                        pendingIncoming.clear()
                    }
                    else -> result.notImplemented()
                }
            }
        }
        handleIncoming(intent)
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
                // Cloud voices fetch audio over the network while the screen is off. Without these locks the
                // phone puts Wi-Fi and the CPU to sleep between pieces and the next request fails.
                "keepAwake" -> {
                    val on = call.arguments as? Boolean ?: false
                    try {
                        if (on) {
                            if (wakeLock == null) {
                                val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                                wakeLock = pm.newWakeLock(android.os.PowerManager.PARTIAL_WAKE_LOCK, "lantern:narration").apply { setReferenceCounted(false) }
                            }
                            if (wifiLock == null) {
                                val wm = applicationContext.getSystemService(WIFI_SERVICE) as android.net.wifi.WifiManager
                                @Suppress("DEPRECATION")
                                val mode = if (android.os.Build.VERSION.SDK_INT >= 29) android.net.wifi.WifiManager.WIFI_MODE_FULL_LOW_LATENCY else android.net.wifi.WifiManager.WIFI_MODE_FULL_HIGH_PERF
                                wifiLock = wm.createWifiLock(mode, "lantern:narration").apply { setReferenceCounted(false) }
                            }
                            // Safety net: released automatically after 3 hours if something goes wrong.
                            wakeLock?.acquire(3 * 60 * 60 * 1000L)
                            wifiLock?.acquire()
                        } else {
                            if (wakeLock?.isHeld == true) wakeLock?.release()
                            if (wifiLock?.isHeld == true) wifiLock?.release()
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("wake", e.message ?: e.toString(), null)
                    }
                }
                "batteryLevel" -> {
                    val bm = getSystemService(android.content.Context.BATTERY_SERVICE) as android.os.BatteryManager
                    result.success(mapOf(
                        "level" to bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY),
                        "charging" to bm.isCharging,
                    ))
                }
                "batteryUnrestricted" -> {
                    val pm = getSystemService(POWER_SERVICE) as android.os.PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(packageName))
                }
                // Sends selected text to a dictionary or translator app (GoldenDict, ColorDict, Google Translate…).
                "processText" -> {
                    val text = call.argument<String>("text") ?: ""
                    val intent = Intent(Intent.ACTION_PROCESS_TEXT).apply {
                        type = "text/plain"
                        putExtra(Intent.EXTRA_PROCESS_TEXT, text)
                        putExtra(Intent.EXTRA_PROCESS_TEXT_READONLY, true)
                    }
                    @Suppress("DEPRECATION")
                    val apps = packageManager.queryIntentActivities(intent, 0).filter { it.activityInfo.packageName != packageName }
                    if (apps.isEmpty()) {
                        result.success(false)
                    } else {
                        startActivity(Intent.createChooser(intent, "Look up with"))
                        result.success(true)
                    }
                }
                "openBatterySettings" -> {
                    try {
                        // App details page: Battery → Unrestricted. Needs no special permission.
                        startActivity(Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, android.net.Uri.parse("package:$packageName")))
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("battery", e.message ?: e.toString(), null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    private var incoming: MethodChannel? = null
    private val pendingIncoming = mutableListOf<Map<String, Any>>()
    private var folderResult: MethodChannel.Result? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncoming(intent)
    }

    /** A book opened or shared from another app: copy it in and tell Dart. */
    private fun handleIncoming(intent: Intent?) {
        if (intent == null || intent.getBooleanExtra("lantern_handled", false)) return
        val uris = mutableListOf<android.net.Uri>()
        when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.let { uris.add(it) }
            Intent.ACTION_SEND -> {
                @Suppress("DEPRECATION")
                (intent.getParcelableExtra<android.os.Parcelable>(Intent.EXTRA_STREAM) as? android.net.Uri)?.let { uris.add(it) }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                @Suppress("DEPRECATION")
                intent.getParcelableArrayListExtra<android.os.Parcelable>(Intent.EXTRA_STREAM)?.forEach { (it as? android.net.Uri)?.let(uris::add) }
            }
        }
        if (uris.isEmpty()) return
        intent.putExtra("lantern_handled", true)
        val main = Handler(Looper.getMainLooper())
        Thread {
            val out = copyUris(uris)
            main.post {
                pendingIncoming.addAll(out)
                incoming?.invokeMethod("ready", null)
            }
        }.start()
    }

    /** Copies content:// or file:// documents into the cache, returning {path, name, size[, error]} for each. */
    private fun copyUris(uris: List<android.net.Uri>): List<Map<String, Any>> {
        val dir = File(cacheDir, "imports").apply { mkdirs() }
        val out = mutableListOf<Map<String, Any>>()
        for ((i, uri) in uris.withIndex()) {
            var name = uri.lastPathSegment?.substringAfterLast('/') ?: "file$i"
            try {
                if (uri.scheme == "content") {
                    contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                        if (c.moveToFirst() && !c.isNull(0)) name = c.getString(0)
                    }
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
        return out
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == PICK_FOLDER) {
            val r = folderResult ?: return
            folderResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                r.success(null)
                return
            }
            try {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) {}
            r.success(uri.toString())
            return
        }
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
            val out = copyUris(uris)
            main.post { result.success(out) }
        }.start()
    }

    companion object {
        private const val PICK_FILES = 4711
        private const val PICK_FOLDER = 4712
    }
}

/** Lists book files in a folder chosen with the system folder picker (and its subfolders). */
object FolderScan {
    fun list(ctx: android.content.Context, tree: android.net.Uri, exts: Set<String>): List<Map<String, Any>> {
        val out = mutableListOf<Map<String, Any>>()
        val root = android.provider.DocumentsContract.getTreeDocumentId(tree)
        walk(ctx, tree, root, exts, out, 0)
        return out
    }

    private fun walk(ctx: android.content.Context, tree: android.net.Uri, docId: String, exts: Set<String>, out: MutableList<Map<String, Any>>, depth: Int) {
        if (depth > 5 || out.size > 3000) return
        val children = android.provider.DocumentsContract.buildChildDocumentsUriUsingTree(tree, docId)
        val cols = arrayOf(
            android.provider.DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            android.provider.DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            android.provider.DocumentsContract.Document.COLUMN_MIME_TYPE,
            android.provider.DocumentsContract.Document.COLUMN_SIZE,
            android.provider.DocumentsContract.Document.COLUMN_LAST_MODIFIED,
        )
        ctx.contentResolver.query(children, cols, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                val id = c.getString(0) ?: continue
                val name = c.getString(1) ?: continue
                if (name.startsWith(".")) continue
                if (c.getString(2) == android.provider.DocumentsContract.Document.MIME_TYPE_DIR) {
                    walk(ctx, tree, id, exts, out, depth + 1)
                } else if (name.substringAfterLast('.', "").lowercase() in exts) {
                    out.add(mapOf(
                        "uri" to android.provider.DocumentsContract.buildDocumentUriUsingTree(tree, id).toString(),
                        "name" to name,
                        "size" to (if (c.isNull(3)) 0L else c.getLong(3)),
                        "modified" to (if (c.isNull(4)) 0L else c.getLong(4)),
                    ))
                }
            }
        }
    }
}

/** Unpacks the pictures of a RAR (CBR) or 7z (CB7) comic into a folder. */
object ArchiveExtractor {
    private val image = Regex("(?i)\\.(jpe?g|png|gif|webp|bmp|avif)$")

    private fun flat(name: String) = name.replace('\\', '/').replace(Regex("[/:]"), "__")

    fun extract(src: File, out: File): Int {
        out.mkdirs()
        val head = ByteArray(8)
        src.inputStream().use { it.read(head) }
        val rar = head[0] == 0x52.toByte() && head[1] == 0x61.toByte() && head[2] == 0x72.toByte() && head[3] == 0x21.toByte()
        val sevenZ = head[0] == 0x37.toByte() && head[1] == 0x7A.toByte() && head[2] == 0xBC.toByte() && head[3] == 0xAF.toByte()
        var n = 0
        when {
            rar -> {
                if (head[6] == 0x01.toByte()) throw IllegalStateException("rar5")
                com.github.junrar.Archive(src).use { a ->
                    for (h in a.fileHeaders) {
                        if (h.isDirectory) continue
                        val name = h.fileName
                        val keep = image.containsMatchIn(name) || name.substringAfterLast('/').substringAfterLast('\\').equals("ComicInfo.xml", true)
                        if (!keep) continue
                        val target = if (name.endsWith("ComicInfo.xml", true)) File(out, "ComicInfo.xml") else File(out, flat(name))
                        target.outputStream().use { a.extractFile(h, it) }
                        n++
                    }
                }
            }
            sevenZ -> {
                org.apache.commons.compress.archivers.sevenz.SevenZFile.builder().setFile(src).get().use { z ->
                    var e = z.nextEntry
                    val buf = ByteArray(64 * 1024)
                    while (e != null) {
                        val name = e.name ?: ""
                        val info = name.substringAfterLast('/').equals("ComicInfo.xml", true)
                        if (!e.isDirectory && (image.containsMatchIn(name) || info)) {
                            File(out, if (info) "ComicInfo.xml" else flat(name)).outputStream().use { o ->
                                while (true) {
                                    val r = z.read(buf)
                                    if (r <= 0) break
                                    o.write(buf, 0, r)
                                }
                            }
                            n++
                        }
                        e = z.nextEntry
                    }
                }
            }
            else -> throw IllegalStateException("unknown")
        }
        return n
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
