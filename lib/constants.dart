// lib/constants.dart
import 'package:flutter/foundation.dart';

// --- Gemini API ---

// IMPORTANT: Use String.fromEnvironment for API key security.
// You'll need to pass this during build:
// flutter build apk --dart-define=GEMINI_API_KEY=YOUR_ACTUAL_API_KEY
// Or configure it in your IDE's run configuration (e.g., VS Code launch.json)
// For debug builds, you might hardcode it temporarily, but NEVER commit it.
const geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  // Provide a default value ONLY for local debugging if needed,
  // otherwise leave it empty or throw an error if not provided.
   defaultValue: 'AIzaSyCdbgTAAnOraRwg-UVpFfpOTpVzT0QrMJg',
);

// Choose your target model consistently
// Options: 'gemini-1.5-flash-latest', 'gemini-1.5-pro-latest', 'gemini-pro' (text only)
// Ensure the model supports the features you need (function calling, vision)
const geminiModelName = 'gemini-2.0-flash'; // Or your preferred model

// --- SharedPreferences Keys ---
const String prefsSettingsKey = 'app_settings';
const String prefsLtmKey = 'long_term_memory_store';
const String prefsCustomToolsKey = 'custom_function_tools';
const String prefsHistoryIndexKey = 'chat_history_index';
const String prefsHistoryPrefix = 'chat_history_';
const String prefsActiveChatIdKey = 'active_chat_id'; // Add if needed

// --- Function Names (Consistent Naming) ---
const String funcSaveLtm = 'save_long_term_memory';
const String funcRetrieveLtm = 'retrieve_long_term_memory';
// Add other known function names if helpful

// --- Default System Prompt ---
const String defaultSystemInstruction = """
You Are Gemini. Advanced AI model Made it by Google Company to every persons can has AI assisant to make life easyier for that User and make them happy.
in Your cnverstions with user Anwer with any language user use that for talking to you else of you want explain or generate code , for them just use English .
Use the provided tools (like long-term memory or custom functions) when appropriate to fulfill user requests.
Be concise when calling functions and clear when explaining results.
""";

// --- Other Constants ---
const int defaultHistoryBufferSize = 20; // Example buffer size