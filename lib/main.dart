// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'pages/code_assistant_page.dart';
import 'services/settings_service.dart';
import 'services/custom_tool_service.dart';
import 'services/long_term_memory_service.dart';
import 'services/input_file_service.dart';
import 'services/ai_helper_service.dart';
import 'services/chat_history_service.dart';
import 'themes.dart'; // <-- Import the themes file
import 'providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Load API Keys (keep as before) ---
  const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyCdbgTAAnOraRwg-UVpFfpOTpVzT0QrMJg',
  );
  const openaiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: 'aa-b1BFjpcQHWHDgTWnpsfTGm7CwueIsSjrbl8UMD5ezCLaBPHY',
  );
  if (geminiApiKey.isEmpty) {
    /* ... error print ... */
  }
  if (openaiApiKey.isEmpty) {
    /* ... warning print ... */
  }

  // --- Initialize Services (keep as before) ---
  final settingsService = SettingsService();
  // Initialize other services...
  final customToolService = CustomToolService();
  final longTermMemoryService = LongTermMemoryService();
  final inputFileService = InputFileService();
  final aiHelperService = AiHelperService(openaiApiKey: openaiApiKey);
  final chatHistoryService = ChatHistoryService();
  final themeProvider = ThemeProvider();

  // Ensure settings are loaded before building MyApp if theme depends on it
  await settingsService.loadSettings(); // Await initial load for theme

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsService),
        // Provide other services...
        ChangeNotifierProvider.value(value: customToolService),
        ChangeNotifierProvider.value(value: longTermMemoryService),
        Provider.value(value: inputFileService),
        Provider.value(value: aiHelperService),
        ChangeNotifierProvider.value(value: chatHistoryService),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: MyApp(geminiApiKey: geminiApiKey),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String geminiApiKey;
  const MyApp({super.key, required this.geminiApiKey});

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsService, ThemeProvider>(
      builder: (context, settings, themeProvider, child) {
        return MaterialApp(
          title: 'Gemini Assistant Enhanced',
          themeMode: settings.themeMode,
          theme: lightTheme,
          darkTheme: themeProvider.currentTheme,
          home:
              geminiApiKey.isEmpty
                  ? const ApiKeyErrorScreen()
                  : CodeAssistantPage(apiKey: geminiApiKey),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

// --- ApiKeyErrorScreen (Keep as before) ---
class ApiKeyErrorScreen extends StatelessWidget {
  const ApiKeyErrorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    // ... implementation ...
    return Scaffold(/* ... */);
  }
}
