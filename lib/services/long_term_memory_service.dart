// lib/services/long_term_memory_service.dart
import 'dart:convert';
import 'package:aiassis/constants.dart' as constants;
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

  MemoryItem({
    required this.id,
    required this.key,
    required this.content,
    required this.timestamp,
  });

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
    if (_prefs == null) await _init();
    final String? memoryJson = _prefs!.getString(
      constants.prefsLtmKey,
    ); // Use constant
    if (memoryJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(memoryJson);
        _memoryItems =
            decodedList
                .map(
                  (item) => MemoryItem.fromJson(item as Map<String, dynamic>),
                )
                .toList();
        _memoryItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      } catch (e, s) {
        // Catch errors
        if (kDebugMode) {
          print("Error loading/decoding long term memory: $e");
          print("Stack trace: $s");
          print("Corrupted JSON string: $memoryJson");
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
    _memoryItems.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final String memoryJson = jsonEncode(
      _memoryItems.map((e) => e.toJson()).toList(),
    );
    await _prefs!.setString(constants.prefsLtmKey, memoryJson); // Use constant
    notifyListeners();
  }

  Future<Map<String, dynamic>> saveMemoryItem(
    String key,
    String content,
  ) async {
    if (key.isEmpty || content.isEmpty) {
      return {
        'status': 'Error',
        'message': 'Both key/topic and content are required to save memory.',
      };
    }
    // Trim input
    final trimmedKey = key.trim();
    final trimmedContent = content.trim();

    try {
      int existingIndex = _memoryItems.indexWhere(
        (item) => item.key.toLowerCase() == trimmedKey.toLowerCase(),
      );

      String userMessage;
      if (existingIndex != -1) {
        _memoryItems[existingIndex].content = trimmedContent;
        _memoryItems[existingIndex].timestamp = DateTime.now();
        userMessage =
            "Successfully updated memory item with key: '$trimmedKey'";
        if (kDebugMode) print("LTM: Updated entry for key '$trimmedKey'");
      } else {
        final newItem = MemoryItem(
          id: _uuid.v4(),
          key: trimmedKey,
          content: trimmedContent,
          timestamp: DateTime.now(),
        );
        _memoryItems.add(newItem);
        userMessage =
            "Successfully saved new memory item with key: '$trimmedKey'";
        if (kDebugMode) print("LTM: Added new entry for key '$trimmedKey'");
      }
      await _saveMemory();
      // Return success map with data (the user message)
      return {'status': 'Success', 'data': userMessage};
    } catch (e) {
      print("LTM: Error saving memory item '$trimmedKey': $e");
      return {
        'status': 'Error',
        'message': 'An internal error occurred while saving the memory item.',
      };
    }
  }

  // Retrieve memory item(s) based on a key or topic query
  // Returns a formatted string for the AI, or an error message.
  Map<String, dynamic> retrieveMemoryItems(String query) {
    if (query.isEmpty) {
      return {
        'status': 'Error',
        'message': 'A query/topic is required to retrieve memory.',
        'data': null,
      };
    }
    final lowerQuery = query.trim().toLowerCase();
    if (lowerQuery.isEmpty) {
      return {
        'status': 'Error',
        'message': 'The memory query cannot be empty.',
        'data': null,
      };
    }
    try {
      final List<MemoryItem> foundItems =
          _memoryItems.where((item) {
            return item.key.toLowerCase().contains(lowerQuery) ||
                item.content.toLowerCase().contains(lowerQuery);
          }).toList();

      if (foundItems.isEmpty) {
        return {
          'status': 'Success',
          'message': "No memory items found matching query: '$query'",
          'data': null,
        };
      }

      // Format results for the model
      StringBuffer buffer = StringBuffer();
      buffer.writeln(
        "Found ${foundItems.length} memory item(s) matching '$query':",
      );
      for (var i = 0; i < foundItems.length; i++) {
        final item = foundItems[i];
        buffer.writeln(
          "${i + 1}. Key: '${item.key}' (Saved: ${item.timestamp.toLocal().toString().substring(0, 16)})",
        );
        buffer.writeln("   Content: ${item.content}");
        if (i < foundItems.length - 1) buffer.writeln();
      }
      if (kDebugMode) {
        print("LTM: Retrieved ${foundItems.length} items for query '$query'");
      }

      return {
        'status': 'Success',
        'message': 'Memory items retrieved successfully',
        'data': buffer.toString(),
      };
    } catch (e) {
      print("LTM: Error retrieving memory items for query '$query': $e");
      return {
        'status': 'Error',
        'message': 'An internal error occurred while retrieving memory items.',
        'data': null,
      };
    }
  }

  Future<void> addMemoryManually(String key, String content) async {
    // Similar to saveMemoryItem, but might be called from UI not function call
    if (key.isEmpty || content.isEmpty) return;
    int existingIndex = _memoryItems.indexWhere(
      (item) => item.key.toLowerCase() == key.toLowerCase(),
    );
    if (existingIndex != -1) {
      _memoryItems[existingIndex].content = content;
      _memoryItems[existingIndex].timestamp = DateTime.now();
    } else {
      final newItem = MemoryItem(
        id: _uuid.v4(),
        key: key,
        content: content,
        timestamp: DateTime.now(),
      );
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
      _memoryItems[index].timestamp =
          DateTime.now(); // Update timestamp on edit
      await _saveMemory();
    }
  }
}
