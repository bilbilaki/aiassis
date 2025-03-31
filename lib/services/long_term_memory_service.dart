// lib/services/long_term_memory_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _ltmKey = 'long_term_memory_store';
var _uuid = Uuid();

class MemoryItem {
  final String id;
  String key; // The topic/key user/model refers to
  String content; // The actual information saved
  DateTime timestamp;

  MemoryItem({required this.id, required this.key, required this.content, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory MemoryItem.fromJson(Map<String, dynamic> json) => MemoryItem(
        id: json['id'] ?? _uuid.v4(), // Assign new ID if missing
        key: json['key'] ?? 'Untitled',
        content: json['content'] ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}

class LongTermMemoryService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<MemoryItem> _memoryItems = [];

  List<MemoryItem> get memoryItems => _memoryItems;

  LongTermMemoryService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadMemory();
  }

  Future<void> loadMemory() async {
    if (_prefs == null) await _init(); // Ensure initialized
    final String? memoryJson = _prefs!.getString(_ltmKey);
    if (memoryJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(memoryJson);
        _memoryItems = decodedList
            .map((item) => MemoryItem.fromJson(item as Map<String, dynamic>))
            .toList();
        // Sort by timestamp descending (newest first)
         _memoryItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e) {
        if (kDebugMode) {
          print("Error loading long term memory: $e");
        }
        _memoryItems = []; // Reset on error
      }
    } else {
      _memoryItems = [];
    }
    notifyListeners();
  }

  Future<void> _saveMemory() async {
    if (_prefs == null) return;
    // Sort before saving
    _memoryItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final String memoryJson = jsonEncode(_memoryItems.map((e) => e.toJson()).toList());
    await _prefs!.setString(_ltmKey, memoryJson);
    notifyListeners(); // Notify listeners after saving potentially changed order/data
  }

  Future<String> saveMemoryItem(String key, String content) async {
     if (key.isEmpty || content.isEmpty) {
      return "Error: Both key/topic and content are required to save memory.";
    }
    // Check if key exists, if so, update it (treat key as unique identifier for content)
     int existingIndex = _memoryItems.indexWhere((item) => item.key.toLowerCase() == key.toLowerCase());

    if (existingIndex != -1) {
       _memoryItems[existingIndex].content = content;
       _memoryItems[existingIndex].timestamp = DateTime.now();
       if (kDebugMode) {
          print("LTM: Updated entry for key '$key'");
        }
    } else {
      final newItem = MemoryItem(
          id: _uuid.v4(), key: key, content: content, timestamp: DateTime.now());
      _memoryItems.add(newItem);
      if (kDebugMode) {
          print("LTM: Added new entry for key '$key'");
        }
    }
    await _saveMemory();
    return "Successfully saved memory item with key: '$key'";
  }

  // Retrieve memory item(s) based on a key or topic query
  // Returns a formatted string for the AI, or an error message.
  String retrieveMemoryItems(String query) {
     if (query.isEmpty) {
      return "Error: A query/topic is required to retrieve memory.";
    }
    final lowerQuery = query.toLowerCase();
    final List<MemoryItem> foundItems = _memoryItems.where((item) {
      return item.key.toLowerCase().contains(lowerQuery) ||
             item.content.toLowerCase().contains(lowerQuery);
    }).toList();

    if (foundItems.isEmpty) {
      return "No memory items found matching query: '$query'";
    }

    // Format results for the model
    StringBuffer buffer = StringBuffer();
    buffer.writeln("Found ${foundItems.length} memory item(s) matching '$query':");
    for (var i = 0; i < foundItems.length; i++) {
      final item = foundItems[i];
      buffer.writeln("${i+1}. Key: '${item.key}' (Saved: ${item.timestamp.toLocal().toString().substring(0,16)})");
      buffer.writeln("   Content: ${item.content}");
      if (i < foundItems.length - 1) buffer.writeln(); // Add spacing
    }
    if (kDebugMode) {
        print("LTM: Retrieved ${foundItems.length} items for query '$query'");
    }
    return buffer.toString();
  }

  Future<void> addMemoryManually(String key, String content) async {
     // Similar to saveMemoryItem, but might be called from UI not function call
     if (key.isEmpty || content.isEmpty) return;
      int existingIndex = _memoryItems.indexWhere((item) => item.key.toLowerCase() == key.toLowerCase());
      if (existingIndex != -1) {
         _memoryItems[existingIndex].content = content;
         _memoryItems[existingIndex].timestamp = DateTime.now();
      } else {
        final newItem = MemoryItem(
            id: _uuid.v4(), key: key, content: content, timestamp: DateTime.now());
        _memoryItems.add(newItem);
      }
      await _saveMemory();
  }

  Future<void> deleteMemoryItemById(String id) async {
    _memoryItems.removeWhere((item) => item.id == id);
    await _saveMemory();
  }

  Future<void> updateMemoryItem(MemoryItem updatedItem) async {
     int index = _memoryItems.indexWhere((item) => item.id == updatedItem.id);
      if (index != -1) {
         _memoryItems[index] = updatedItem;
         _memoryItems[index].timestamp = DateTime.now(); // Update timestamp on edit
         await _saveMemory();
      }
  }
}