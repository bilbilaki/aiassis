// lib/services/chat_history_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_history_model.dart';
import '../constants.dart' as constants; // Use constants

// For ChatMessage

const _historyIndexKey = 'chat_history_index'; // Stores list of chat IDs
const _historyPrefix = 'chat_history_'; // Prefix for individual chat data keys
var _uuid = Uuid();

class ChatHistoryService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<ChatSessionItem> _chatSessions = [];
  String? _activeChatId; // ID of the currently loaded chat

  List<ChatSessionItem> get chatSessions => _chatSessions;
  String? get activeChatId => _activeChatId;

  ChatHistoryService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadHistoryIndex();
    // Optionally load the last active chat? Or force new chat on start?
    // startNewChat(); // Start with a fresh chat by default
  }

  Future<void> loadHistoryIndex() async {
    if (_prefs == null) await _init();
    // No JSON decoding here, just getting a list of strings
    final List<String>? chatIds = _prefs!.getStringList(
      constants.prefsHistoryIndexKey,
    ); // Use constant

    if (chatIds != null) {
      _chatSessions = [];
      List<String> validIds = []; // Keep track of IDs that load successfully
      for (String id in chatIds) {
        final session = await loadChatSession(
          id,
        ); // loadChatSession handles its own errors
        if (session != null) {
          _chatSessions.add(session);
          validIds.add(id); // Add to valid list
        } else {
          debugPrint(
            "Warning: Chat ID $id data is missing or corrupt. It will be removed from index.",
          );
        }
      }
      // --- Optional Cleanup: Remove bad IDs from the index ---
      if (validIds.length != chatIds.length) {
        await _prefs!.setStringList(constants.prefsHistoryIndexKey, validIds);
        debugPrint("Cleaned chat history index.");
      }
      _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    } else {
      _chatSessions = [];
    }
    // Load active chat ID
    _activeChatId = _prefs!.getString(
      constants.prefsActiveChatIdKey,
    ); // Use constant

    notifyListeners();
  }

  Future<ChatSessionItem?> loadChatSession(String id) async {
     if (_prefs == null) await _init();
     final String? sessionJson = _prefs!.getString('${constants.prefsHistoryPrefix}$id'); // Use constant
     if (sessionJson != null) {
        try {
           // The ChatSessionItem.fromJson should ideally have its own try-catch
           // for robustness within the model itself, as shown in your original code.
           return ChatSessionItem.fromJson(jsonDecode(sessionJson));
        } catch (e, s) { // Catch decoding error here too
           debugPrint("Error decoding chat session $id: $e");
           debugPrint("Stack trace: $s");
           debugPrint("Corrupted JSON: $sessionJson");
           // Optionally remove the corrupted entry
           // await _prefs!.remove('${constants.prefsHistoryPrefix}$id');
           return null;
        }
     }
     return null;
  }

  Future<void> saveChatSession(ChatSessionItem session) async {
    if (_prefs == null) await _init();
    session.lastModified = DateTime.now();
    final String sessionJson = jsonEncode(session.toJson()); // Assumes session.toJson is safe
    await _prefs!.setString('${constants.prefsHistoryPrefix}${session.id}', sessionJson); // Use constant


    // Update index if it's a new session or ensure it exists
    final List<String> chatIds = _prefs!.getStringList(constants.prefsHistoryIndexKey) ?? [];
    if (!chatIds.contains(session.id)) {
      chatIds.add(session.id);
      await _prefs!.setStringList(constants.prefsHistoryIndexKey, chatIds);
    }

      // Add to local list if new and reload wasn't triggered elsewhere
         final index = _chatSessions.indexWhere((s) => s.id == session.id);
    if (index != -1) {
        _chatSessions[index] = session;
    } else {
        _chatSessions.add(session);
    }
    _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));

    // Save active ID
    setActiveChatId(session.id); // This handles saving the active ID

    notifyListeners(); // Notify after all updates
  }

    
  // Creates a new, empty chat session and sets it as active
  ChatSessionItem startNewChat() {
    final newSession = ChatSessionItem(
      id: _uuid.v4(),
      title: 'New Chat', // Will be updated on first message
      createdAt: DateTime.now(),
      lastModified: DateTime.now(),
      messages: [],
    );
    _activeChatId = newSession.id;
    // Don't save it immediately, save on first message or action
    // Optionally, add to the beginning of the list for immediate UI update
    // _chatSessions.insert(0, newSession); // Add temporarily until saved
    // notifyListeners();
    debugPrint("Started new chat session: ID = ${newSession.id}");
    return newSession; // Return the new session object
  }

  Future<void> deleteChatSession(String id) async {
    if (_prefs == null) await _init();
    // Remove from storage
    await _prefs!.remove('$_historyPrefix$id');

    // Remove from index
    final List<String> chatIds = _prefs!.getStringList(_historyIndexKey) ?? [];
    chatIds.remove(id);
    await _prefs!.setStringList(_historyIndexKey, chatIds);

    // Remove from local list
    _chatSessions.removeWhere((session) => session.id == id);

    // If the deleted chat was active, start a new one or load another?
    if (_activeChatId == id) {
      _activeChatId = null; // Or load the top one?
    }

    notifyListeners();
  }

  // Helper to set the active chat ID - used when user selects from history
  void setActiveChatId(String? id) {
    if (_activeChatId != id) {
      _activeChatId = id;
      // Save the active ID to SharedPreferences
      if (id != null) {
        _prefs?.setString(constants.prefsActiveChatIdKey, id); // Use constant
      } else {
        _prefs?.remove(constants.prefsActiveChatIdKey);
      }
      notifyListeners();
      debugPrint("Set active chat ID to: $id");
    }
  }
}
