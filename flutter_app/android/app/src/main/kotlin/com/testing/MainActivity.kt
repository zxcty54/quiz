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
                                llmInference = null
                                System.gc()

                                // Gemma 2B CPU INT4 exact optimal limits
                                val options = LlmInference.LlmInferenceOptions.builder()
                                    .setModelPath(modelPath)
                                    .setMaxTokens(384)
                                    .setMaxSequenceLength(512)
                                    .build()
                                    
                                llmInference = LlmInference.createFromOptions(applicationContext, options)
                                runOnUiThread { result.success(true) }
                            } catch (e: Throwable) {
                                runOnUiThread { result.error("INIT_FAIL", e.message ?: "Model load failed", null) }
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
                        result.error("ENGINE_NOT_READY", "Gemma Model Not Initialized", null)
                        return@setMethodCallHandler
                    }

                    val cleanInput = rawPrompt.trim()
                    if (cleanInput.isEmpty()) {
                        result.error("EMPTY_PROMPT", "Prompt cannot be empty", null)
                        return@setMethodCallHandler
                    }

                    executor.execute {
                        try {
                            // Clean Gemma 2B Persona Instruction Format
                            val gemmaFormattedPrompt = "<start_of_turn>user\nYou are a helpful and direct AI assistant. Answer the user prompt accurately, concisely, and naturally.\n\nUser Query: $cleanInput<end_of_turn>\n<start_of_turn>model\n"
                            
                            val response = engine.generateResponse(gemmaFormattedPrompt)
                            
                            runOnUiThread {
                                if (!response.isNullOrBlank()) {
                                    val cleanResponse = response
                                        .replace("<start_of_turn>model", "")
                                        .replace("<end_of_turn>", "")
                                        .replace("<eos>", "")
                                        .trim()
                                    result.success(cleanResponse)
                                } else {
                                    result.error("EMPTY_RESPONSE", "Engine returned no output", null)
                                }
                            }
                        } catch (e: Throwable) {
                            runOnUiThread { 
                                result.error("GEN_FAIL", e.localizedMessage ?: "Inference execution error", null) 
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
