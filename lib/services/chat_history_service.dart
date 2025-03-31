// lib/services/chat_history_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_history_model.dart';
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
    final List<String>? chatIds = _prefs!.getStringList(_historyIndexKey);

    if (chatIds != null) {
      _chatSessions = []; // Clear existing before loading
      for (String id in chatIds) {
        final session = await loadChatSession(id);
        if (session != null) {
          _chatSessions.add(session);
        } else {
           // ID exists in index but data is missing/corrupt - clean up index?
           debugPrint("Warning: Chat ID $id found in index but data is missing.");
        }
      }
      // Sort by last modified date, newest first
      _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));
    } else {
      _chatSessions = [];
    }
    notifyListeners();
  }

  Future<ChatSessionItem?> loadChatSession(String id) async {
     if (_prefs == null) await _init();
     final String? sessionJson = _prefs!.getString('$_historyPrefix$id');
     if (sessionJson != null) {
        try {
           return ChatSessionItem.fromJson(jsonDecode(sessionJson));
        } catch (e) {
           debugPrint("Error decoding chat session $id: $e");
            // If decode fails, maybe delete the bad entry?
            // await deleteChatSession(id); // Be cautious with auto-delete
           return null;
        }
     }
     return null;
  }

  Future<void> saveChatSession(ChatSessionItem session) async {
    if (_prefs == null) await _init();
    session.lastModified = DateTime.now(); // Update timestamp on save
    final String sessionJson = jsonEncode(session.toJson());
    await _prefs!.setString('$_historyPrefix${session.id}', sessionJson);

    // Update index if it's a new session or ensure it exists
    final List<String> chatIds = _prefs!.getStringList(_historyIndexKey) ?? [];
    if (!chatIds.contains(session.id)) {
      chatIds.add(session.id);
      await _prefs!.setStringList(_historyIndexKey, chatIds);
       // Add to local list if new and reload wasn't triggered elsewhere
       if(!_chatSessions.any((s)=>s.id == session.id)){
           _chatSessions.add(session);
           _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified)); // Keep sorted
           notifyListeners();
       }
    }
    else{
        // If existing, update the object in the local list
        final index = _chatSessions.indexWhere((s) => s.id == session.id);
        if(index != -1){
            _chatSessions[index] = session;
            // Re-sort as lastModified changed
            _chatSessions.sort((a, b) => b.lastModified.compareTo(a.lastModified));
            notifyListeners();
        }
    }
    _activeChatId = session.id; // Mark as active after saving
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
          notifyListeners(); // Optionally notify if UI depends on active ID state
          debugPrint("Set active chat ID to: $id");
      }
  }
}