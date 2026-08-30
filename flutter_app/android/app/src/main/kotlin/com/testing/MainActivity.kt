package com.testing

import android.os.Bundle
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mocktester.ai/offline_llm"
    private var llmInference: LlmInference? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath != null && File(modelPath).exists()) {
                        thread {
                            try {
                                val options = LlmInference.LlmInferenceOptions.builder()
                                    .setModelPath(modelPath)
                                    .setMaxTokens(512)
                                    .build()
                                llmInference = LlmInference.createFromOptions(applicationContext, options)
                                runOnUiThread { result.success(true) }
                            } catch (e: Throwable) {
                                runOnUiThread { result.error("INIT_FAIL", e.message ?: "Init failed", null) }
                            }
                        }
                    } else {
                        result.error("FILE_NOT_FOUND", "Model file not found at path", null)
                    }
                }
                "generate" -> {
                    val rawPrompt = call.argument<String>("prompt") ?: ""
                    val engine = llmInference
                    
                    if (engine == null) {
                        result.error("ENGINE_NOT_READY", "Model is not initialized", null)
                        return@setMethodCallHandler
                    }

                    if (rawPrompt.trim().isEmpty()) {
                        result.error("EMPTY_PROMPT", "Prompt cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    thread {
                        try {
                            // Gemma 2B formatting wrapper to prevent parser crash
                            val formattedPrompt = "<start_of_turn>user\n$rawPrompt<end_of_turn>\n<start_of_turn>model\n"
                            val response = engine.generateResponse(formattedPrompt)
                            runOnUiThread { result.success(response) }
                        } catch (e: Throwable) {
                            runOnUiThread { result.error("GEN_FAIL", e.message ?: "Generation error", null) }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
