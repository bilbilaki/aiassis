// lib/pages/code_assistant_page.dart
// ignore_for_file: deprecated_member_use, avoid_print, invalid_return_type_for_catch_error, unreachable_switch_default, duplicate_ignore

import 'dart:async';
import 'dart:convert';
import 'dart:io';
// For image bytes
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:google_generative_ai/google_generative_ai.dart'
    hide FunctionResponse; // Avoid naming conflict
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:audioplayers/audioplayers.dart'; // For playback
import 'package:clipboard/clipboard.dart'; // Specific clipboard package

import '../services/settings_service.dart';
import '../services/custom_tool_service.dart';
import '../services/long_term_memory_service.dart';
import '../services/input_file_service.dart'; // Added
import '../services/ai_helper_service.dart'; // Added
import '../services/chat_history_service.dart'; // Added
import '../models/chat_history_model.dart'; // Added
import 'settings_page.dart';
import '../constants.dart' as constants;
import '../providers/theme_provider.dart';

// --- Message Type Enum and Updated ChatMessage Class ---
// (Ensure this is defined HERE or imported correctly if in its own file)
enum MessageType { text, image, audio, error, functionResponse }

class ChatMessage {
  final String text;
  final bool isUserMessage;
  final MessageType type;
  final DateTime timestamp;
  final String? imagePath;
  final String? audioPath;
  final Duration? audioDuration; // Make duration optional

  ChatMessage({
    required this.text,
    required this.isUserMessage,
    required this.type,
    DateTime? timestamp,
    this.imagePath,
    this.audioPath,
    this.audioDuration,
  }) : timestamp = timestamp ?? DateTime.now();

  Content toContent() {
    // History content generation logic (as defined previously)
    if (type == MessageType.text) {
      return isUserMessage
          ? Content.text(text)
          : Content.model([TextPart(text)]);
    } else if (type == MessageType.image && imagePath != null) {
      final imageText =
          text.isNotEmpty
              ? text
              : "[User sent an image: ${imagePath?.split('/').last}]";
      // For now, represent image as text in history
      return isUserMessage
          ? Content.text(imageText)
          : Content.model([TextPart(text)]);
    } else {
      String historyText = text;
      if (type == MessageType.audio) {
        historyText = "[User sent audio recording. Transcription: \"$text\"]";
      }
      if (type == MessageType.functionResponse) {
        historyText = "[Function Result: $text]";
      }
      if (type == MessageType.error) historyText = "[System Error Message]";
      return isUserMessage
          ? Content.text(historyText)
          : Content.model([TextPart(historyText)]);
    }
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUserMessage': isUserMessage,
    'type': type.name,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
    'audioPath': audioPath,
    'audioDurationMillis': audioDuration?.inMilliseconds,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    MessageType msgType = MessageType.text;
    try {
      msgType = MessageType.values.byName(json['type'] ?? 'text');
    } catch (_) {}
    final durationMillis = json['audioDurationMillis'] as int?;
    return ChatMessage(
      text: json['text'] ?? '',
      isUserMessage: json['isUserMessage'] ?? false,
      type: msgType,
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      imagePath: json['imagePath'] as String?,
      audioPath: json['audioPath'] as String?,
      audioDuration:
          durationMillis != null
              ? Duration(milliseconds: durationMillis)
              : null,
    );
  }
}

// --- Main Chat Screen Widget ---
class CodeAssistantPage extends StatefulWidget {
  final String apiKey;
  const CodeAssistantPage({super.key, required this.apiKey});

  @override
  State<CodeAssistantPage> createState() => _CodeAssistantPageState();
}

class _CodeAssistantPageState extends State<CodeAssistantPage>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>(); // For drawer
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<ChatMessage> _messages = []; // Current chat messages
  bool _isLoading = false; // General loading state (API calls)
  bool _isInitializing = true; // Model initialization
  bool _isRecording = false;
  bool _isTranscribing = false; // Specific state for transcription
  File? _selectedImage; // Hold selected image file before sending

  // Services
  late SettingsService _settingsService;
  late CustomToolService _customToolService;
  late LongTermMemoryService _longTermMemoryService;
  late InputFileService _inputFileService; // Added
  late AiHelperService _aiHelperService; // Added
  late ChatHistoryService _chatHistoryService; // Added

  // Gemini specific
  GenerativeModel? _model;
  ChatSession? _chat;
  ChatSessionItem? _currentChatSession; // Holds the current active session data

  // Audio Playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingAudioPath;
  PlayerState _currentPlayerState = PlayerState.stopped;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _settingsService = Provider.of<SettingsService>(context, listen: false);
    _customToolService = Provider.of<CustomToolService>(context, listen: false);
    _longTermMemoryService = Provider.of<LongTermMemoryService>(
      context,
      listen: false,
    );
    _inputFileService = Provider.of<InputFileService>(context, listen: false);
    _aiHelperService = Provider.of<AiHelperService>(context, listen: false);
    _chatHistoryService = Provider.of<ChatHistoryService>(
      context,
      listen: false,
    );

    // Listen to text controller to toggle Send/Record button
    _textController.addListener(_handleTextChange);

    // Listen to chat history changes to potentially update the current session if needed
    // (e.g., if another device modifies history - less common for SP)
    // _chatHistoryService.addListener(_handleHistoryChange);

    // --- Initialize Audio Player Listeners ---
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (!mounted) return;
      setState(() {
        _currentPlayerState = state;
      });
      // Reset position/duration display when stopped/completed
      if (state == PlayerState.stopped || state == PlayerState.completed) {
        setState(() {
          _audioPosition = Duration.zero;
          if (state == PlayerState.completed) {
            _currentlyPlayingAudioPath = null; // Deselect on completion
          }
        });
      }
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (!mounted) return;
      setState(() {
        _audioDuration = duration;
      });
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (!mounted) return;
      setState(() {
        _audioPosition = position;
      });
    });

    // --- Load Initial Chat ---
    _loadInitialChat();

    // _initializeChat(); // Moved to _loadInitialChat
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.removeListener(_handleTextChange);
    _textController.dispose();
    _scrollController.dispose();
    _inputFileService.disposeRecorder(); // Release recorder resources
    _playerStateSubscription?.cancel(); // Cancel audio subscriptions
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _audioPlayer.dispose(); // Dispose audio player
    // _chatHistoryService.removeListener(_handleHistoryChange);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Optional: Stop recording if app goes into background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isRecording) {
        print("App paused/inactive, stopping recording...");
        _stopRecording(cancelled: true); // Cancel recording if app is suspended
      }
      _audioPlayer.pause(); // Pause playback
    }
    if (state == AppLifecycleState.detached) {
      _inputFileService.disposeRecorder(); // Ensure cleanup if app is killed
      _audioPlayer.dispose();
    }
  }

  // --- Initialization and Chat Loading ---

  Future<void> _loadInitialChat() async {
    setState(() {
      _isInitializing = true;
      _isLoading = true;
    });
    // Try to load the last active chat ID, or start new if none
    final initialChatId = _chatHistoryService.activeChatId;
    if (initialChatId != null) {
      await _loadChat(initialChatId);
    } else {
      _startNewChat(); // Will also call _initializeChat
    }
    if (mounted) {
      setState(() {
        _isInitializing = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadChat(String sessionId) async {
    debugPrint("Loading chat session: $sessionId");
    setState(() {
      _isLoading = true;
    });
    final session = await _chatHistoryService.loadChatSession(sessionId);
    if (session != null && mounted) {
      setState(() {
        _currentChatSession = session;
        _messages = List.from(session.messages); // Copy messages
        _chatHistoryService.setActiveChatId(sessionId); // Ensure service knows
        _selectedImage = null; // Clear any pending image
        _textController.clear(); // Clear input
      });
      await _initializeChat(
        history: _getChatHistoryBuffer(),
      ); // Initialize Gemini with loaded history
    } else {
      // Handle error or session not found -> start new chat
      _startNewChat();
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom(durationMillis: 100); // Scroll after loading
    }
  }

  void _startNewChat() {
    debugPrint("Starting new chat...");
    setState(() {
      _isLoading = true;
    });
    final newSession = _chatHistoryService.startNewChat();
    if (mounted) {
      setState(() {
        _currentChatSession = newSession;
        _messages = []; // Clear messages
        _chatHistoryService.setActiveChatId(newSession.id);
        _selectedImage = null;
        _textController.clear();
      });
      _initializeChat(history: []); // Initialize Gemini with empty history
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Initialize or re-initialize the Gemini Model and Chat Session
  Future<void> _initializeChat({List<Content>? history}) async {
    if (!mounted) return;
    setState(() {
      _isInitializing = true;
      _isLoading = true;
      _model = null;
      _chat = null;
    });

    // Fetch settings and tools (keep logic from previous step)
    final temperature = _settingsService.temperature;
    final topK = _settingsService.topK;
    final topP = _settingsService.topP;
    final maxOutputTokens = _settingsService.maxOutputTokens;
    // Use default from constants if service returns empty/null, or handle in service
    final systemInstructionText =
        _settingsService.systemInstruction.isNotEmpty
            ? _settingsService.systemInstruction
            : constants.defaultSystemInstruction;

    final ltmSaveDeclaration = FunctionDeclaration(
      constants.funcSaveLtm, // Use constant
      "Saves a piece of information provided by the user or inferred from the conversation to the assistant's long-term memory. Use a concise key or topic name.",
      Schema(
        SchemaType.object,
        properties: {
          'key': Schema(
            SchemaType.string,
            description:
                'A short, descriptive key or topic for the memory item (e.g., "user_preference_color", "project_deadline").',
          ),
          'content': Schema(
            SchemaType.string,
            description: 'The actual information or data to be saved.',
          ),
        },
        requiredProperties: ['key', 'content'],
      ),
    );

    final ltmRetrieveDeclaration = FunctionDeclaration(
      constants.funcRetrieveLtm, // Use constant
      "Retrieves saved information from the assistant's long-term memory based on a query or topic.",
      Schema(
        SchemaType.object,
        properties: {
          'query': Schema(
            SchemaType.string,
            description:
                'The key, topic, or search term to look for in the long-term memory (e.g., "user_preference_color", "project", "deadline").',
          ),
        },
        requiredProperties: ['query'],
      ),
    );

    // --- Get Custom Tools ---
    final customDeclarations =
        _customToolService.functionDeclarations; // Already gets valid ones

    // --- Combine Tools ---
    final allToolDeclarations = [
      ltmSaveDeclaration,
      ltmRetrieveDeclaration,
      ...customDeclarations,
    ];
    final toolsList =
        allToolDeclarations.isNotEmpty
            ? [Tool(functionDeclarations: allToolDeclarations)]
            : null;

    // --- Check API Key ---
    final apiKey =
        widget
            .apiKey; // Or directly use constants.geminiApiKey if not passed via widget
    if (apiKey.isEmpty) {
      print("ERROR: Gemini API Key is missing!");
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isLoading = false;
        });
        _addMessage(
          "Configuration Error: Gemini API Key is missing. Please set it up.",
          isUser: false,
          type: MessageType.error,
        );
      }
      return; // Stop initialization
    }

    try {
      _model = GenerativeModel(
        model: constants.geminiModelName, // Use constant
        apiKey: apiKey, // Use validated key
        generationConfig: GenerationConfig(
          temperature: temperature,

          maxOutputTokens: maxOutputTokens,
          // Optional: Add stop sequences if needed
          // stopSequences: ['\n---'],
        ),
        systemInstruction: Content.system(systemInstructionText),
        tools: toolsList,
        // --- Configure Safety Settings (Example: Block fewer things - adjust carefully!) ---
        safetySettings: [
          // HarmSetting(HarmCategory.harassment, HarmBlockThreshold.medium),
          // HarmSetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
          // HarmSetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
          // HarmSetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
          // Use only if needed and understand the risks
          SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.none),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.none),
        ],
        toolConfig:
            toolsList != null
                ? ToolConfig(
                  // Consider AUTO vs ANY. AUTO lets model decide, ANY forces a function call if possible.
                  functionCallingConfig: FunctionCallingConfig(
                    mode: FunctionCallingMode.auto,
                  ),
                )
                : null,
      );

      // Start chat with provided history
      final effectiveHistory = history ?? _getChatHistoryBuffer();
      _chat = _model!.startChat(history: effectiveHistory);

      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isLoading = false;
        });
        debugPrint(
          "Chat initialized. Model: ${constants.geminiModelName}, History: ${effectiveHistory.length}, Tools: ${allToolDeclarations.map((e) => e.name).join(', ')}",
        );
      }
    } catch (e) {
      print("Error initializing chat: $e");
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _isLoading = false;
        });
        // Provide a more specific error message if possible
        String errorMessage = "Error initializing AI Model.";
        if (e is GenerativeAIException) {
          errorMessage += " (${e.message})";
        } else {
          errorMessage += " ($e)";
        }
        _addMessage(errorMessage, isUser: false, type: MessageType.error);
      }
    }
  }

  // Get history buffer based on settings (unchanged from previous)
  List<Content> _getChatHistoryBuffer() {
    final bufferSize = _settingsService.messageBufferSize;
    if (bufferSize <= 0 || _messages.isEmpty) return [];
    // Use toContent() which now handles different message types for history
    return _messages.reversed
        .take(bufferSize)
        .map((msg) => msg.toContent())
        .where(
          (content) => content.role != 'error',
        ) // Filter out invalid content placeholders
        .toList()
        .reversed
        .toList();
  }

  // --- Message Handling ---

  Future<void> _saveCurrentChat() async {
    if (_currentChatSession != null) {
      // Update the session's message list before saving
      _currentChatSession!.messages = List.from(_messages);
      await _chatHistoryService.saveChatSession(_currentChatSession!);
      debugPrint("Chat session ${_currentChatSession!.id} saved.");
    }
  }

  void _addMessage(
    String text, {
    required bool isUser,
    required MessageType type,
    String? imagePath,
    String? audioPath,
    Duration? audioDuration,
  }) {
    if (!mounted) return;

    // Don't add duplicate system/error messages quickly
    if (!isUser &&
        _messages.isNotEmpty &&
        _messages.last.text == text &&
        (_messages.last.type == MessageType.error ||
            _messages.last.type == MessageType.functionResponse)) {
      print("Skipping duplicate system message.");
      return;
    }

    final message = ChatMessage(
      text: text,
      isUserMessage: isUser,
      type: type,
      imagePath: imagePath,
      audioPath: audioPath,
      audioDuration: audioDuration,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(message);
    });

    // Save chat history after adding a message (user or AI)
    _saveCurrentChat();

    // Auto-scroll after adding message
    _scrollToBottom();
  }

  // --- Smooth Scrolling Logic ---
  void _scrollToBottom({int durationMillis = 300, bool jump = false}) {
    if (!_scrollController.hasClients) return;

    // Use WidgetsBinding to schedule scroll after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return; // Check again inside callback

      final maxExtent = _scrollController.position.maxScrollExtent;
      final currentExtent = _scrollController.position.pixels;
      final threshold = 50.0; // Only animate if not already near the bottom

      if (maxExtent - currentExtent > threshold || jump) {
        if (jump || durationMillis <= 0) {
          _scrollController.jumpTo(maxExtent);
        } else {
          _scrollController.animateTo(
            maxExtent,
            duration: Duration(milliseconds: durationMillis),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  // --- Input Handling (Typing, Buttons) ---

  bool _showSendButton = false;

  void _handleTextChange() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (hasText != _showSendButton) {
      setState(() {
        _showSendButton = hasText;
      });
    }

    // Optional: Add typing indicator logic here if needed
    // _typingTimer?.cancel();
    // _typingTimer = Timer(Duration(seconds: 2), () { /* User stopped typing */ });
  }

  // --- Image Picking Logic ---
  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || _isRecording) return; // Don't allow while busy
    final result = await _inputFileService.pickImage(source);
    if (result.success && result.file != null && mounted) {
      setState(() {
        _selectedImage = result.file;
      });
      _showImagePreviewAndSend();
    } else if (result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show a confirmation/preview for the image before adding text/sending
  void _showImagePreviewAndSend() {
    if (_selectedImage == null) return;

    File imageFile = _selectedImage!; // Capture locally

    // Clear the selection immediately to allow picking another one if cancelled
    setState(() {
      _selectedImage = null;
    });

    // Show a bottom sheet or dialog to add text and confirm send
    showModalBottomSheet(
      context: context,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Send Image?",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Image.file(imageFile, height: 150, fit: BoxFit.contain),
                const SizedBox(height: 10),
                TextField(
                  controller:
                      _textController, // Reuse main controller temporarily
                  decoration: const InputDecoration(
                    hintText: 'Add optional text...',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        _textController.clear(); // Clear text if cancelled
                        Navigator.of(ctx).pop();
                      },
                      child: const Text("Cancel"),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text("Send"),
                      onPressed: () {
                        // Call send with the captured image file
                        _sendMessageWithData(imageFile: imageFile);
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      // When closed without sending, clear the text controller
    ).whenComplete(
      () => {
        // Check if image was sent, if not clear controller?
        // It's cleared within the send logic now.
      },
    );
  }

  // --- Audio Recording Logic ---
  Future<void> _startRecording() async {
    if (_isLoading || _isInitializing) return;
    // Ensure not already recording
    if (await _inputFileService.isRecording()) {
      print("Already recording!");
      return;
    }

    setState(() {
      _isRecording = true;
    });
    bool success = await _inputFileService.startRecording();
    if (!success && mounted) {
      setState(() {
        _isRecording = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to start recording. Check permissions?"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopRecording({bool cancelled = false}) async {
    if (!_isRecording) return; // Avoid stopping if not recording

    setState(() {
      _isRecording = false;
    }); // Update UI immediately

    final result = await _inputFileService.stopRecording();

    if (cancelled) {
      print("Recording cancelled by user or app state.");
      // Optionally delete the partial file if needed
      if (result.path != null) {
        File(result.path!).delete().catchError(
          (e) => print("Error deleting cancelled recording: $e"),
        );
      }
      return;
    }

    if (result.success && result.path != null) {
      debugPrint("Recording successful: ${result.path}");
      setState(() {
        _isTranscribing = true;
      }); // Show transcribing indicator

      final audioPath = result.path!;
      //  final audioFile = result.file!;

      // Get audio duration for display before transcription
      Duration? duration;
      try {
        final tempPlayer =
            AudioPlayer(); // Use a temporary player to get duration
        await tempPlayer.setSourceDeviceFile(audioPath);
        duration = await tempPlayer.getDuration();
        await tempPlayer.dispose();
      } catch (e) {
        print("Could not get audio duration: $e");
      }

      // Add audio message bubble locally FIRST
      _addMessage(
        "Audio Recording", // Placeholder text
        isUser: true,
        type: MessageType.audio,
        audioPath: audioPath,
        audioDuration: duration,
      );

      // Then, transcribe
      final transcription = await _aiHelperService.transcribeAudio(audioPath);

      setState(() {
        _isTranscribing = false;
      }); // Hide transcribing indicator

      if (transcription != null &&
          !transcription.startsWith("Error:") &&
          !transcription.startsWith("Exception:")) {
        debugPrint("Transcription: $transcription");
        // Send the transcription text to Gemini
        _sendMessageWithData(transcription: transcription);

        // Optional: Update the local audio message text with the transcription?
        int messageIndex = _messages.lastIndexWhere(
          (m) => m.audioPath == audioPath,
        );
        if (messageIndex != -1) {
          setState(() {
            _messages[messageIndex] = ChatMessage(
              text: transcription,
              isUserMessage: true,
              type: MessageType.text,
              timestamp: DateTime.now(),
            );
          });
        }
      } else {
        debugPrint("Transcription failed or returned error: $transcription");
        // Add an error message *instead* of sending to Gemini
        _addMessage(
          transcription ?? "Failed to transcribe audio.",
          isUser: false, // Show as system/error message
          type: MessageType.error,
        );
        // Keep the audio bubble, user can still play it
      }
    } else if (result.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --- Audio Playback Logic ---
  Future<void> _playPauseAudio(String path) async {
    if (_currentlyPlayingAudioPath == path &&
        _currentPlayerState == PlayerState.playing) {
      // Pause
      await _audioPlayer.pause();
    } else {
      // Stop previous playback if different file
      if (_currentlyPlayingAudioPath != null &&
          _currentlyPlayingAudioPath != path) {
        await _audioPlayer.stop();
        setState(() {
          // Reset state for the old playing item
        });
      }
      // Play or Resume
      setState(() {
        _currentlyPlayingAudioPath = path;
      });
      try {
        await _audioPlayer.play(
          DeviceFileSource(path),
        ); // Use DeviceFileSource for local files
      } catch (e) {
        print("Error playing audio: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error playing audio: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _currentlyPlayingAudioPath = null;
        }); // Reset on error
      }
    }
  }

  // --- Central Sending Logic ---
  Future<void> _sendMessageWithData({
    File? imageFile,
    String? transcription,
  }) async {
    if (_isLoading || _isInitializing || _chat == null) return; // Basic checks

    final String textFromInput = _textController.text.trim();
    List<Part> parts = []; // Use Gemini's Part type
    bool isUserAction =
        true; // Assume user action unless only transcription is sent without UI interaction

    // --- Prepare content parts ---
    if (imageFile != null) {
      // Handle Image Message
      try {
        Uint8List imageBytes = await imageFile.readAsBytes();
        // Determine MIME type (basic example, might need 'mime' package for robust detection)
        String mimeType = 'image/jpeg'; // Default
        if (imageFile.path.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        }
        if (imageFile.path.toLowerCase().endsWith('.webp')) {
          mimeType = 'image/webp';
        }
        if (imageFile.path.toLowerCase().endsWith('.heic')) {
          mimeType = 'image/heic';
        }
        if (imageFile.path.toLowerCase().endsWith('.heif')) {
          mimeType = 'image/heif';
        }

        parts.add(DataPart(mimeType, imageBytes));

        // Add text if provided WITH the image
        if (textFromInput.isNotEmpty) {
          parts.add(TextPart(textFromInput));
        }

        // Add image message to local UI immediately
        _addMessage(
          textFromInput, // Store associated text
          isUser: true,
          type: MessageType.image,
          imagePath: imageFile.path, // Store path for display
        );
      } catch (e) {
        print("Error reading image file: $e");
        _addMessage(
          "Error processing image file.",
          isUser: false,
          type: MessageType.error,
        );
        return; // Don't proceed if image fails
      }
    } else if (transcription != null) {
      // Handle Audio Transcription Message (UI message was already added)
      parts.add(TextPart(transcription)); // Send transcription as text
      isUserAction =
          false; // This is result of transcription, not direct typing
    } else if (textFromInput.isNotEmpty) {
      // Handle Simple Text Message
      parts.add(TextPart(textFromInput));
      _addMessage(textFromInput, isUser: true, type: MessageType.text);
    } else {
      // No text, no image, no transcription - do nothing
      return;
    }

    // --- Clear inputs after processing ---
    if (isUserAction) {
      // Only clear text input if it was a direct user send action
      _textController.clear();
    }
    // _selectedImage is cleared during preview/send logic

    // --- Send to Gemini ---
    if (parts.isEmpty) {
      print("Cannot send empty message parts.");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final content = Content.multi(
        parts,
      ); // Use multiPart for image/text combo
      final response = await _chat!.sendMessage(content);

      // Process response (Text and Function Calls)
      final responseText = response.text;
      final functionCalls = response.functionCalls.toList();

      if (responseText != null && responseText.trim().isNotEmpty) {
        _addMessage(responseText, isUser: false, type: MessageType.text);
      }

      if (functionCalls.isNotEmpty) {
        for (final call in functionCalls) {
          await _handleFunctionCall(call); // Existing function call handler
        }
      } else if ((responseText == null || responseText.trim().isEmpty) &&
          functionCalls.isEmpty) {
        print("Received empty response without function calls.");
        _addMessage(
          "Received an empty response.",
          isUser: false,
          type: MessageType.error,
        );
      }
    } on GenerativeAIException catch (e) {
      print("GenerativeAIException sending message: ${e.message}");
      _addMessage(
        "API Error: ${e.message}.",
        isUser: false,
        type: MessageType.error,
      );
    } catch (e) {
      print("Error sending message: $e");
      _addMessage(
        "Sorry, an error occurred: $e",
        isUser: false,
        type: MessageType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- Function Call Handler (Keep existing logic from previous step)  ---
  Future<void> _handleFunctionCall(FunctionCall call) async {
    // ... (Keep the exact implementation from the previous step)
    Map<String, dynamic> functionResultMap;
    String uiFeedbackMessage =
        "Executing function ${call.name}..."; // Initial feedback
    MessageType responseType = MessageType.functionResponse; // Default type

    try {
      if (kDebugMode) {
        // Use kDebugMode check
        print("Handling function call: ${call.name}");
        print("Args: ${call.args}");
      }

      switch (call.name) {
        case constants.funcSaveLtm: // Use constant
          final key = call.args['key'] as String?;
          final content = call.args['content'] as String?;
          // Check arguments *before* calling the service
          if (key != null && content != null) {
            // Service now returns the standard map
            functionResultMap = await _longTermMemoryService.saveMemoryItem(
              key,
              content,
            );
          } else {
            functionResultMap = {
              'status': 'Error',
              'message':
                  "Missing 'key' or 'content' argument for ${call.name}.",
            };
          }
          break; // Don't forget break!

        case constants.funcRetrieveLtm: // Use constant
          final query = call.args['query'] as String?;
          if (query != null) {
            // Service now returns the standard map
            functionResultMap = _longTermMemoryService.retrieveMemoryItems(
              query,
            );
          } else {
            functionResultMap = {
              'status': 'Error',
              'message': "Missing 'query' argument for ${call.name}.",
            };
          }
          break;

        default:
          // --- Custom Tool Execution ---
          if (_customToolService.customTools.any((t) => t.name == call.name)) {
            // Assume executeCustomTool also returns the standard map
            functionResultMap = await _customToolService.executeCustomTool(
              call.name,
              call.args,
            );
          } else {
            // Unknown function
            functionResultMap = {
              'status': 'Error',
              'message': "Unknown function requested: ${call.name}",
            };
          }
      }

      // --- Process the result map ---
      if (functionResultMap['status'] == 'Error') {
        uiFeedbackMessage =
            "Function Error (${call.name}): ${functionResultMap['message']}";
        responseType = MessageType.error; // Mark as error in UI
        if (kDebugMode) print(uiFeedbackMessage);
      } else {
        // Extract success data for UI feedback (might be a string or other structure)
        var successData = functionResultMap['data'];
        uiFeedbackMessage =
            "Function Result (${call.name}): ${successData is String ? successData : 'Completed successfully.'}";
        responseType = MessageType.functionResponse;
        if (kDebugMode) print("Function ${call.name} executed successfully.");
      }

      // Add UI message reflecting function execution status
      _addMessage(uiFeedbackMessage, isUser: false, type: responseType);

      // --- Send Function Response back to the Model ---
      // Gemini expects the result in a specific format within the FunctionResponse content
      // The 'response' part should contain the data the *model* needs, which might be
      // the raw data from the 'data' field or the error message.
      final responseDataForModel =
          functionResultMap['status'] == 'Error'
              ? {
                'error': functionResultMap['message'],
              } // Send error message back
              : functionResultMap['data']; // Send actual data back on success

      final responseContent = Content.functionResponse(
        call.name,
        responseDataForModel,
      );

      // Check if chat session still exists
      if (_chat == null) {
        print("Error: Chat session is null. Cannot send function response.");
        _addMessage(
          "Error: Cannot continue chat after function call (session lost).",
          isUser: false,
          type: MessageType.error,
        );
        return;
      }

      // --- Send response and get model's next message ---
      setState(() => _isLoading = true); // Indicate loading for model response
      final responseAfterFunc = await _chat!.sendMessage(responseContent);
      setState(() => _isLoading = false);

      // --- Handle model's response after function call ---
      final responseText = responseAfterFunc.text;
      if (responseText != null && responseText.trim().isNotEmpty) {
        _addMessage(responseText, isUser: false, type: MessageType.text);
      }

      // Handle potential subsequent function calls
      if (responseAfterFunc.functionCalls.isNotEmpty) {
        if (kDebugMode) {
          print("Model requested another function call after ${call.name}");
        }
        for (final nextCall in responseAfterFunc.functionCalls) {
          await _handleFunctionCall(nextCall); // Recursive call
        }
      } else if (responseText == null || responseText.trim().isEmpty) {
        if (kDebugMode) {
          print("Model had no text response after function call ${call.name}.");
        }
        // Optionally add a small note? Or just do nothing.
        _addMessage(
          "[Model provided no further text response]",
          isUser: false,
          type: MessageType.functionResponse,
        );
      }
    } catch (e, s) {
      // Catch unexpected errors during handling
      print("Error handling function call ${call.name}: $e");
      print("Stack trace: $s");
      // Add error message to UI
      _addMessage(
        "Critical Error processing function call ${call.name}: $e",
        isUser: false,
        type: MessageType.error,
      );
      // Should we attempt to send an error back to the model? Maybe not here.
      // Reset loading state if it was set
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI Build Methods ---

  @override
  Widget build(BuildContext context) {
    // Use Consumer for chat history service to rebuild drawer when needed
    return Consumer<ChatHistoryService>(
      builder: (context, historyService, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(
              _currentChatSession?.displayTitle ?? 'Gemini Assistant',
              style: theme.textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              tooltip: 'Open Menu',
            ),
            actions: [
              // Model selector dropdown
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        'Gemini', // This should be dynamic based on your model selection
                    isDense: true,
                    items:
                        ['Gemini'].map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (newValue) {
                      // Handle model change
                    },
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              // Fantasy Theme Toggle
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  final isFantasy = themeProvider.isFantasyMode;
                  return IconButton(
                    icon: Icon(
                      isFantasy ? Icons.nightlight_round : Icons.flare_outlined,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: isFantasy ? 'Dark Mode' : 'Fantasy Mode',
                    onPressed: () {
                      themeProvider.toggleFantasyTheme();
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: () {
                  _audioPlayer.pause();
                  setState(() {
                    _currentlyPlayingAudioPath = null;
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  ).then((_) {
                    _checkSettingsAndReinitialize();
                  });
                },
              ),
            ],
            elevation: 0,
            backgroundColor: colorScheme.surface,
            scrolledUnderElevation: 2,
          ),
          drawer: _buildHistoryDrawer(historyService),
          body: Column(
            children: [
              // --- Chat Message List ---
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
                ),
              ),
              // --- Loading / Recording / Transcribing Indicators ---
              if (_isLoading || _isRecording || _isTranscribing)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border(
                      top: BorderSide(
                        color: colorScheme.outlineVariant.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isRecording)
                        Icon(Icons.mic, color: colorScheme.error, size: 20),
                      if (!_isRecording)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colorScheme.primary,
                          ),
                        ),
                      const SizedBox(width: 10),
                      Text(
                        _isRecording
                            ? 'Recording...'
                            : _isTranscribing
                            ? 'Transcribing...'
                            : _isInitializing
                            ? 'Initializing...'
                            : 'Generating...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              // --- Input Area ---
              _buildInputArea(),
            ],
          ),
        );
      },
    );
  }

  // Method to check if re-initialization is needed after settings change
  void _checkSettingsAndReinitialize() {
    // Simple check: If critical generative params changed, reload.
    // A more robust way would be иметь a flag in SettingsService or compare old vs new values.
    print("Checking if re-initialization is needed after settings...");
    // For simplicity, assume any navigation back from Settings might require it
    // In a real app, compare specific critical settings before reloading.
    _initializeChat(history: _getChatHistoryBuffer());
  }

  // --- Build History Drawer ---
  Widget _buildHistoryDrawer(ChatHistoryService historyService) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withOpacity(0.5),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Chat History',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: colorScheme.primary,
                  ),
                  tooltip: 'New Chat',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _startNewChat();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: historyService.chatSessions.length,
              itemBuilder: (context, index) {
                final session = historyService.chatSessions[index];
                final bool isActive = session.id == historyService.activeChatId;
                return Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? colorScheme.primaryContainer : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            isActive
                                ? colorScheme.primary
                                : colorScheme.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color:
                            isActive
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      session.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color:
                            isActive
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurface,
                        fontWeight: isActive ? FontWeight.w600 : null,
                      ),
                    ),
                    subtitle: Text(
                      'Last activity: ${session.lastModified.toLocal().toString().substring(0, 16)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            isActive
                                ? colorScheme.onPrimaryContainer.withOpacity(
                                  0.7,
                                )
                                : colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      tooltip: 'Delete Chat',
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder:
                              (ctx) => AlertDialog(
                                title: Text(
                                  'Delete Chat?',
                                  style: theme.textTheme.titleLarge,
                                ),
                                content: Text(
                                  'Are you sure you want to delete the chat "${session.displayTitle}"? This cannot be undone.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.of(ctx).pop(false),
                                    child: Text(
                                      'Cancel',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.error,
                                    ),
                                    onPressed:
                                        () => Navigator.of(ctx).pop(true),
                                    child: Text(
                                      'Delete',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(color: colorScheme.error),
                                    ),
                                  ),
                                ],
                              ),
                        );
                        if (confirm == true) {
                          await historyService.deleteChatSession(session.id);
                          if (isActive) {
                            _startNewChat();
                          }
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      if (!isActive) {
                        _loadChat(session.id);
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Build Message Bubble ---
  Widget _buildMessageBubble(ChatMessage message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final alignment =
        message.isUserMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start;
    final margin =
        message.isUserMessage
            ? const EdgeInsets.only(top: 4, bottom: 4, left: 60, right: 8)
            : const EdgeInsets.only(top: 4, bottom: 4, right: 60, left: 8);

    Color bubbleColor;
    Color textColor = colorScheme.onSurface;

    switch (message.type) {
      case MessageType.error:
        bubbleColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        break;
      case MessageType.functionResponse:
        bubbleColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
        break;
      case MessageType.audio:
        bubbleColor =
            message.isUserMessage
                ? colorScheme.secondaryContainer
                : colorScheme.surfaceContainerHighest;
        textColor =
            message.isUserMessage
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant;
        break;
      case MessageType.image:
      case MessageType.text:
      default:
        bubbleColor =
            message.isUserMessage
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest;
        textColor =
            message.isUserMessage
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant;
    }

    return Container(
      margin: margin,
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft:
                          message.isUserMessage
                              ? const Radius.circular(16)
                              : const Radius.circular(4),
                      bottomRight:
                          message.isUserMessage
                              ? const Radius.circular(4)
                              : const Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildMessageContent(message, textColor),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 4.0, top: 4.0),
                child: IconButton(
                  icon: Icon(
                    Icons.copy_outlined,
                    size: 16,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  tooltip: 'Copy Text',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    String textToCopy = message.text;
                    if (message.type == MessageType.image) {
                      textToCopy =
                          "[Image${message.text.isNotEmpty ? ': ${message.text}' : ''}]";
                    }
                    if (message.type == MessageType.audio) {
                      textToCopy =
                          "[Audio Recording${message.text.isNotEmpty ? ' Transcription: ${message.text}' : ''}]";
                    }

                    FlutterClipboard.copy(textToCopy)
                        .then((_) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        })
                        .catchError((e) => print("Clipboard error: $e"));
                  },
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4.0, right: 8.0, left: 8.0),
            child: Text(
              TimeOfDay.fromDateTime(message.timestamp).format(context),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Build Content Inside Bubble ---
  Widget _buildMessageContent(ChatMessage message, Color textColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    switch (message.type) {
      case MessageType.text:
      case MessageType.error:
      case MessageType.functionResponse:
        // Use Markdown for AI responses, regular Text for others/errors/functions
        // Enable selection for both
        return SelectionArea(
          child:
              message.isUserMessage ||
                      message.type == MessageType.error ||
                      message.type == MessageType.functionResponse
                  ? Text(message.text, style: TextStyle(color: textColor))
                  : MarkdownBody(
                    data: message.text,
                    selectable:
                        false, // Selection handled by SelectionArea parent
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: textColor), // Apply text color
                    ),
                  ),
        );

      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imagePath != null)
              ClipRRect(
                // Add rounded corners to image
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(message.imagePath!),
                  width: 200, // Max width
                  height: 200, // Max height
                  fit: BoxFit.cover,
                  // Error builder for image loading issues
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 200,
                      height: 100,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    );
                  },
                ),
              ),
            if (message.text.isNotEmpty) ...[
              const SizedBox(height: 8),
              SelectionArea(
                child: Text(message.text, style: TextStyle(color: textColor)),
              ),
            ],
          ],
        );

      case MessageType.audio:
        Color iconColor =
            message.isUserMessage
                ? colorScheme.secondary
                : colorScheme.primary; // Example icon colors
        Color sliderActiveColor =
            message.isUserMessage ? colorScheme.secondary : colorScheme.primary;
        Color sliderInactiveColor = sliderActiveColor.withOpacity(0.3);

        final isPlaying =
            _currentlyPlayingAudioPath == message.audioPath &&
            (_currentPlayerState == PlayerState.playing ||
                _currentPlayerState == PlayerState.paused);
        final currentPosition = isPlaying ? _audioPosition : Duration.zero;
        final totalDuration =
            message.audioDuration ??
            (isPlaying ? _audioDuration : Duration.zero);

        return Container(
          // width: 200, // Constrain width
          child: Row(
            mainAxisSize: MainAxisSize.min, // Keep row tight
            children: [
              IconButton(
                icon: Icon(
                  isPlaying && _currentPlayerState == PlayerState.playing
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  size: 36,
                  color: iconColor,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed:
                    message.audioPath != null
                        ? () => _playPauseAudio(message.audioPath!)
                        : null, // Disable if path is missing
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Keep column tight
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text.startsWith(
                            'Error',
                          ) // Show transcription or placeholder
                          ? "Audio Recording" // Fallback / Error text
                          : (message.text.isNotEmpty &&
                              message.text != "Audio Recording")
                          ? '"${message.text}"' // Show transcription if available
                          : "Audio Recording",
                      style: TextStyle(
                        color: textColor.withOpacity(0.8),
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (totalDuration >
                        Duration
                            .zero) // Show slider/time only if duration known
                      Row(
                        children: [
                          Text(
                            _formatDuration(currentPosition),
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              // Customize slider appearance
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.0,
                                thumbShape: RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0,
                                ),
                                overlayShape: RoundSliderOverlayShape(
                                  overlayRadius: 12.0,
                                ),
                                thumbColor:
                                    message.isUserMessage
                                        ? sliderActiveColor
                                        : sliderInactiveColor,
                                activeTrackColor:
                                    message.isUserMessage
                                        ? sliderActiveColor
                                        : sliderInactiveColor,
                                inactiveTrackColor:
                                    message.isUserMessage
                                        ? sliderInactiveColor
                                        : sliderActiveColor,
                              ),
                              child: Slider(
                                value: currentPosition.inMilliseconds
                                    .toDouble()
                                    .clamp(
                                      0.0,
                                      totalDuration.inMilliseconds.toDouble(),
                                    ),
                                min: 0.0,
                                max: totalDuration.inMilliseconds.toDouble(),
                                onChanged: (value) async {
                                  if (_currentlyPlayingAudioPath ==
                                      message.audioPath) {
                                    await _audioPlayer.seek(
                                      Duration(milliseconds: value.toInt()),
                                    );
                                  } else {
                                    // If not playing this track, maybe start playing and seek?
                                    // Or just update visually if needed, but seeking usually implies playback intent.
                                  }
                                },
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(totalDuration),
                            style: TextStyle(
                              fontSize: 12,
                              color: textColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );

      default:
        return SelectionArea(
          child: Text(message.text, style: TextStyle(color: textColor)),
        );
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  // --- Build Input Area (Major changes) ---
  Widget _buildInputArea() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.add_circle_outline,
                  color: colorScheme.primary,
                ),
                tooltip: 'Attach File',
                onSelected: (value) {
                  switch (value) {
                    case 'camera':
                      _pickImage(ImageSource.camera);
                      break;
                    case 'gallery':
                      _pickImage(ImageSource.gallery);
                      break;
                  }
                },
                itemBuilder:
                    (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'camera',
                        child: ListTile(
                          leading: Icon(
                            Icons.camera_alt,
                            color: colorScheme.primary,
                          ),
                          title: Text(
                            'Camera',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'gallery',
                        child: ListTile(
                          leading: Icon(
                            Icons.photo_library,
                            color: colorScheme.primary,
                          ),
                          title: Text(
                            'Gallery',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                enabled: !_isLoading && !_isRecording && !_isTranscribing,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _textController,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: 'Type message...',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                    ),
                    enabled: !_isLoading && !_isRecording && !_isTranscribing,
                    onSubmitted:
                        (_) => _showSendButton ? _sendMessageWithData() : null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child:
                    _showSendButton
                        ? IconButton(
                          key: const ValueKey('send_button'),
                          icon: Icon(
                            Icons.send_rounded,
                            color: colorScheme.primary,
                          ),
                          tooltip: 'Send Message',
                          onPressed:
                              (_isLoading || _isInitializing || _isTranscribing)
                                  ? null
                                  : () => _sendMessageWithData(),
                        )
                        : GestureDetector(
                          key: const ValueKey('record_button'),
                          onLongPressStart: (_) => _startRecording(),
                          onLongPressEnd: (_) => _stopRecording(),
                          onLongPressCancel:
                              () => _stopRecording(cancelled: true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: EdgeInsets.all(_isRecording ? 14 : 10),
                            decoration: BoxDecoration(
                              color:
                                  _isRecording
                                      ? colorScheme.error
                                      : colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mic,
                              color:
                                  _isRecording
                                      ? colorScheme.onError
                                      : colorScheme.onPrimary,
                              size: _isRecording ? 28 : 24,
                            ),
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
