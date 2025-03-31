// lib/services/settings_service.dart
import 'package:flutter/material.dart'; // Import material for ThemeMode
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys for SharedPreferences
const _temperatureKey = 'gemini_temperature';
const _topKKey = 'gemini_top_k';
const _topPKey = 'gemini_top_p';
const _maxTokensKey = 'gemini_max_output_tokens';
const _systemInstructionKey = 'gemini_system_instruction';
const _messageBufferSizeKey = 'gemini_message_buffer_size';
const _themeModeKey = 'app_theme_mode'; // <-- New key for theme

// Default System Instruction (keep as before)
const _defaultSystemInstruction = /* ... */ '''
You are advanced AI agent Assistant for USER . You most flowing this rule\'s in all your conversation with USER :
1- USER real language is Farsi but It will understand English to some extent. So in any case, speak to the USER in whatever language they speak to you, except for coding and development issues, which should only be in English.
2- If, when responding to a user\'s request, the answer you provided was generated through a text generation algorithm based on the text of artificial intelligence models, state that and provide an approximate percentage for its effectiveness.
3- If your information or the information provided by the user is not sufficient for a correct answer to a question, avoid creating a contrived or hasty answer by stating this and requesting more information.
4- When generating code or scripts, if you intend to modify a code several times in a row and only a few lines of the original code change, you are allowed to summarize the generated code by fully indicating where the change was made.
5-In all conversations with a user, when an idea, code, or script is shared with you, you are allowed to review and analyze it thoroughly and must report any bugs and solutions to the user.''';


class SettingsService with ChangeNotifier {
 SharedPreferences? _prefs;

 // --- Default Values ---
 double _temperature = 1.0;
 int _topK = 40;
 double _topP = 0.95;
 int _maxOutputTokens = 8192;
 String _systemInstruction = _defaultSystemInstruction;
 int _messageBufferSize = 7;
 ThemeMode _themeMode = ThemeMode.system; // <-- Default to system theme

 // --- Getters ---
 double get temperature => _temperature;
 int get topK => _topK;
 double get topP => _topP;
 int get maxOutputTokens => _maxOutputTokens;
 String get systemInstruction => _systemInstruction;
 int get messageBufferSize => _messageBufferSize;
 ThemeMode get themeMode => _themeMode; // <-- Getter for theme

 SettingsService() {
 _init();
 }

 Future<void> _init() async {
 _prefs = await SharedPreferences.getInstance();
 await loadSettings();
 }

 Future<void> loadSettings() async {
 if (_prefs == null) await _init();

 _temperature = _prefs!.getDouble(_temperatureKey) ?? _temperature;
 _topK = _prefs!.getInt(_topKKey) ?? _topK;
 _topP = _prefs!.getDouble(_topPKey) ?? _topP;
 _maxOutputTokens = _prefs!.getInt(_maxTokensKey) ?? _maxOutputTokens;
 _systemInstruction = _prefs!.getString(_systemInstructionKey) ?? _systemInstruction;
 _messageBufferSize = _prefs!.getInt(_messageBufferSizeKey) ?? _messageBufferSize;

 // Load theme mode from preferences
 final themeString = _prefs!.getString(_themeModeKey);
 if (themeString != null) {
 _themeMode = ThemeMode.values.firstWhere(
 (e) => e.toString() == themeString,
 orElse: () => ThemeMode.system, // Fallback to system if value is invalid
 );
 } else {
 _themeMode = ThemeMode.system; // Default if not set
 }


 notifyListeners();
 }

 // --- Setters (Save on change) ---

 // ... (Keep existing setters for temp, topK, topP, etc.) ...
 Future<void> setTemperature(double value) async {
  if (value < 0) value = 0;
  if (value > 2.0) value = 2.0; // Gemini range often 0-2
  if (_temperature == value) return;
  _temperature = value;
  await _prefs?.setDouble(_temperatureKey, value);
  notifyListeners();
 }

 Future<void> setTopK(int value) async {
  if (value <= 0) value = 1; // TopK must be > 0
  if (_topK == value) return;
  _topK = value;
  await _prefs?.setInt(_topKKey, value);
  notifyListeners();
 }

 Future<void> setTopP(double value) async {
  if (value <= 0) value = 0.01;
  if (value > 1.0) value = 1.0;
  if (_topP == value) return;
  _topP = value;
  await _prefs?.setDouble(_topPKey, value);
  notifyListeners();
 }

 Future<void> setMaxOutputTokens(int value) async {
  if (value <= 0) value = 1;
  if (_maxOutputTokens == value) return;
  _maxOutputTokens = value;
  await _prefs?.setInt(_maxTokensKey, value);
  notifyListeners();
 }

 Future<void> setSystemInstruction(String value) async {
  if (_systemInstruction == value) return;
  _systemInstruction = value;
  await _prefs?.setString(_systemInstructionKey, value);
  notifyListeners();
 }

 Future<void> setMessageBufferSize(int value) async {
  if (value < 0) value = 0;
  if (value > 50) value = 50;
  if (_messageBufferSize == value) return;
  _messageBufferSize = value;
  await _prefs?.setInt(_messageBufferSizeKey, value);
  notifyListeners();
 }


 // Setter for ThemeMode
 Future<void> setThemeMode(ThemeMode mode) async {
 if (_themeMode == mode) return;
 _themeMode = mode;
 await _prefs?.setString(_themeModeKey, mode.toString()); // Store as string
 notifyListeners();
 }

 Future<void> resetToDefaults() async {
 _temperature = 1.0;
 _topK = 40;
 _topP = 0.95;
 _maxOutputTokens = 8192;
 _systemInstruction = _defaultSystemInstruction;
 _messageBufferSize = 7;
 _themeMode = ThemeMode.system; // <-- Reset theme mode

 // Remove keys from prefs or set them to defaults
 await _prefs?.remove(_temperatureKey);
 await _prefs?.remove(_topKKey);
 await _prefs?.remove(_topPKey);
 await _prefs?.remove(_maxTokensKey);
 await _prefs?.remove(_systemInstructionKey);
 await _prefs?.remove(_messageBufferSizeKey);
 await _prefs?.remove(_themeModeKey); // <-- Remove theme mode key

 notifyListeners();
 }
}