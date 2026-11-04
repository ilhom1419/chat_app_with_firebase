package com.portfolio.chat_app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import kotlin.concurrent.thread

class MainActivity : FlutterFragmentActivity() {
    private val SCREEN_CHANNEL = "screen_protector"
    private val TRIMMER_CHANNEL = "video_trimmer"
    private val SHARE_CHANNEL = "app_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Native Android Share Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "shareText") {
                val text = call.argument<String>("text")
                val subject = call.argument<String>("subject")
                if (text != null) {
                    val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(android.content.Intent.EXTRA_TEXT, text)
                        if (subject != null) putExtra(android.content.Intent.EXTRA_SUBJECT, subject)
                    }
                    val chooser = android.content.Intent.createChooser(intent, subject ?: "Ulashish")
                    chooser.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(chooser)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENTS", "Text cannot be null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // Screen protector channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "enableSecure") {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else if (call.method == "disableSecure") {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // Native Video Trimmer channel using Android MediaExtractor & MediaMuxer
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TRIMMER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "trimVideo") {
                val inputPath = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                val startMs = call.argument<Number>("startMs")?.toLong() ?: 0L
                val endMs = call.argument<Number>("endMs")?.toLong() ?: 0L

                if (inputPath == null || outputPath == null || endMs <= startMs) {
                    result.error("INVALID_ARGUMENTS", "Invalid video trimming arguments", null)
                    return@setMethodCallHandler
                }

                thread {
                    try {
                        trimVideo(inputPath, outputPath, startMs, endMs)
                        runOnUiThread {
                            result.success(outputPath)
                        }
                    } catch (e: Exception) {
                        runOnUiThread {
                            result.error("TRIM_ERROR", e.localizedMessage ?: "Trimming failed", null)
                        }
                    }
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun trimVideo(inputPath: String, outputPath: String, startMs: Long, endMs: Long) {
        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        val outputFile = File(outputPath)
        if (outputFile.exists()) {
            outputFile.delete()
        }

        val muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        val trackCount = extractor.trackCount
        val indexMap = HashMap<Int, Int>(trackCount)
        var bufferSize = 1024 * 1024

        for (i in 0 until trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("video/") || mime.startsWith("audio/")) {
                extractor.selectTrack(i)
                val dstIndex = muxer.addTrack(format)
                indexMap[i] = dstIndex
                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    val newSize = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE)
                    if (newSize > bufferSize) {
                        bufferSize = newSize
                    }
                }
            }
        }

        if (indexMap.isEmpty()) {
            extractor.release()
            muxer.release()
            throw IllegalArgumentException("No video or audio tracks found in source file")
        }

        // Set orientation hint if video track format contains it
        for (i in 0 until trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: ""
            if (mime.startsWith("video/") && format.containsKey(MediaFormat.KEY_ROTATION)) {
                muxer.setOrientationHint(format.getInteger(MediaFormat.KEY_ROTATION))
                break
            }
        }

        muxer.start()

        val startUs = startMs * 1000L
        val endUs = endMs * 1000L

        extractor.seekTo(startUs, MediaExtractor.SEEK_TO_CLOSEST_SYNC)

        val dstBuf = ByteBuffer.allocate(bufferSize)
        val bufferInfo = MediaCodec.BufferInfo()

        try {
            while (true) {
                bufferInfo.offset = 0
                bufferInfo.size = extractor.readSampleData(dstBuf, 0)
                if (bufferInfo.size < 0) {
                    bufferInfo.size = 0
                    break
                } else {
                    bufferInfo.presentationTimeUs = extractor.sampleTime
                    if (bufferInfo.presentationTimeUs > endUs) {
                        break
                    }
                    if (bufferInfo.presentationTimeUs >= startUs) {
                        bufferInfo.flags = extractor.sampleFlags
                        val trackIndex = extractor.sampleTrackIndex
                        val dstTrack = indexMap[trackIndex]
                        if (dstTrack != null) {
                            muxer.writeSampleData(dstTrack, dstBuf, bufferInfo)
                        }
                    }
                    extractor.advance()
                }
            }
        } finally {
            try {
                muxer.stop()
            } catch (_: Exception) {}
            muxer.release()
            extractor.release()
        }
    }
}
