package com.testing

import android.os.Bundle
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.mocktester.ai/offline_llm"
    private var llmInference: LlmInference? = null
    private val executor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    if (modelPath != null && File(modelPath).exists()) {
                        executor.execute {
                            try {
                                // Destroy old instance to avoid OOM
                                llmInference = null
                                System.gc()

                                // Minimal stable parameters for low RAM & Qwen/Gemma compatibility
                                val options = LlmInference.LlmInferenceOptions.builder()
                                    .setModelPath(modelPath)
                                    .setMaxTokens(384)
                                    .setMaxSequenceLength(512)
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
                        result.error("ENGINE_NOT_READY", "MediaPipe Model Not Initialized", null)
                        return@setMethodCallHandler
                    }

                    val cleanInput = rawPrompt.trim()
                    if (cleanInput.isEmpty()) {
                        result.error("EMPTY_PROMPT", "Prompt cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            // Direct execution without extra prompt wrappers to prevent crash
                            val response = engine.generateResponse(cleanInput)
                            
                            runOnUiThread {
                                if (!response.isNullOrBlank()) {
                                    val cleanResponse = response
                                        .replace("<|im_end|>", "")
                                        .replace("<|endoftext|>", "")
                                        .replace("<end_of_turn>", "")
                                        .trim()
                                    result.success(cleanResponse)
                                } else {
                                    result.error("EMPTY_RESPONSE", "Engine returned no output", null)
                                }
                            }
                        } catch (e: Throwable) {
                            runOnUiThread { 
                                result.error("GEN_FAIL", e.localizedMessage ?: "Inference error", null) 
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        executor.shutdown()
        llmInference = null
    }
}
