// lib/models/chat_history_model.dart
// ignore_for_file: unused_import

import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../pages/code_assistant_page.dart'; // Import ChatMessage definition

var _uuid = Uuid();

class ChatSessionItem {
  String id;
  String title; // Can be first message, timestamp, or user-defined
  DateTime createdAt;
  DateTime lastModified;
  List<ChatMessage> messages; // The core history

  ChatSessionItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastModified,
    required this.messages,
  });


  // --- Serialization for SharedPreferences ---

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'lastModified': lastModified.toIso8601String(),
        // Serialize messages carefully: Convert ChatMessage objects to JSON
        'messages': messages.map((msg) => msg.toJson()).toList(),
      };

  factory ChatSessionItem.fromJson(Map<String, dynamic> json) {
      try {
          return ChatSessionItem(
            id: json['id'] ?? _uuid.v4(), // Generate ID if missing
            title: json['title'] ?? 'Chat Session',
            createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
            lastModified: DateTime.tryParse(json['lastModified'] ?? '') ?? DateTime.now(),
            // Deserialize messages: Convert JSON maps back to ChatMessage objects
            messages: (json['messages'] as List<dynamic>?)
                    ?.map((msgJson) => ChatMessage.fromJson(msgJson as Map<String, dynamic>))
                    .toList() ??
                [],
          );
      } catch (e) {
          print("Error deserializing ChatSessionItem: $e");
          print("Problematic JSON: $json");
          // Return a default/empty item on error
           return ChatSessionItem(
               id: _uuid.v4(),
               title: 'Error Loading Chat',
               createdAt: DateTime.now(),
               lastModified: DateTime.now(),
               messages: []
           );
      }
  }


  // Helper to get a concise title if not set properly
  String get displayTitle {
     if (title.isNotEmpty && title != 'Chat Session') return title;
     if (messages.isNotEmpty) {
         final firstUserMsg = messages.firstWhere((m) => m.isUserMessage, orElse: () => messages.first);
         return firstUserMsg.text.length > 30
             ? '${firstUserMsg.text.substring(0, 30)}...'
             : firstUserMsg.text;
     }
     return createdAt.toLocal().toString().substring(0, 16); // Fallback to timestamp
  }
}

// --- Add toJson/fromJson to ChatMessage in code_assistant_page.dart ---
// Modify the ChatMessage class IN lib/pages/code_assistant_page.dart like this:

/*
// In lib/pages/code_assistant_page.dart:

enum MessageType { text, image, audio, error, functionResponse } // Added enum

class ChatMessage {
  final String text;
  final bool isUserMessage;
  // Remove individual booleans, use type enum
  // final bool isError;
  // final bool isFunctionResponse;
  final MessageType type;
  final DateTime timestamp;
  final String? imagePath; // Store local path for display
  final String? audioPath; // Store local path for display
  final Duration? audioDuration; // Store duration for display

  ChatMessage({
    required this.text,
    required this.isUserMessage,
    required this.type,
    DateTime? timestamp,
    this.imagePath,
    this.audioPath,
    this.audioDuration, // Make duration optional
  }) : timestamp = timestamp ?? DateTime.now();


  // Helper to create Content object for Gemini history
  Content toContent() {
    // Only send text and image messages to Gemini history for now
    if (type == MessageType.text) {
      return isUserMessage ? Content.text(text) : Content.model([TextPart(text)]);
    } else if (type == MessageType.image && imagePath != null) {
       // For history, we might just send the text description or omit the image
       // depending on how much context Gemini needs vs history size limits.
       // Let's include the text if present, otherwise just indicate an image was sent.
       final imageText = text.isNotEmpty ? text : "[User sent an image]";
       return isUserMessage ? Content.text(imageText) : Content.model([TextPart(text)]); // Or Content.text("[AI Sent Image]")
       // Ideally, if Gemini supported images in history, you'd construct Content.parts here.
    } else {
      // Represent audio/other types simply as text in history
      String historyText = text;
      if(type == MessageType.audio) historyText = "[User sent audio: \"$text\"]"; // Use transcript
      if(type == MessageType.functionResponse) historyText = "[Function Result: $text]";
      if(type == MessageType.error) historyText = "[System Error Message]";
       return isUserMessage ? Content.text(historyText) : Content.model([TextPart(historyText)]);
    }
  }


  // --- Serialization ---
   Map<String, dynamic> toJson() => {
        'text': text,
        'isUserMessage': isUserMessage,
        'type': type.name, // Store enum name as string
        'timestamp': timestamp.toIso8601String(),
        'imagePath': imagePath,
        'audioPath': audioPath,
        'audioDurationMillis': audioDuration?.inMilliseconds, // Store duration
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
      MessageType msgType = MessageType.text; // Default
      try {
           msgType = MessageType.values.byName(json['type'] ?? 'text');
      } catch (_) {
           // Handle cases where enum name might be invalid in old data
      }
      final durationMillis = json['audioDurationMillis'] as int?;

      return ChatMessage(
        text: json['text'] ?? '',
        isUserMessage: json['isUserMessage'] ?? false,
        type: msgType,
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
        imagePath: json['imagePath'] as String?,
        audioPath: json['audioPath'] as String?,
        audioDuration: durationMillis != null ? Duration(milliseconds: durationMillis) : null,
      );
    }
}

*/