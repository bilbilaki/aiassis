// lib/services/input_file_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart'; // For kIsWeb, Platform
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:file_picker/file_picker.dart'; // Uncomment if using generic file picker
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Use 'as p' to avoid conflict

enum PickedFileType { image, audio, other }

class PickedFileResult {
  final File? file;
  final String? path; // Path might be needed even if File object exists
  final PickedFileType type;
  final String? errorMessage;

  PickedFileResult({this.file, this.path, required this.type, this.errorMessage});

  bool get success => file != null && errorMessage == null;
}

class InputFileService {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _currentRecordingPath;

  // --- Permission Handling ---

  Future<bool> _requestPermission(Permission permission) async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
       // Permissions work differently on desktop/web - assume granted or OS handles it
       return true;
    }
    // Primarily for Android/iOS
    final status = await permission.request();
    return status.isGranted || status.isLimited; // Limited grants access too
  }

  Future<bool> requestCameraPermission() => _requestPermission(Permission.camera);
  Future<bool> requestPhotosPermission() => _requestPermission(Permission.photos); // Or Permission.storage on older Android
  Future<bool> requestMicrophonePermission() => _requestPermission(Permission.microphone);

  // --- Image Picking ---

  Future<PickedFileResult> pickImage(ImageSource source) async {
    bool hasPermission = true;
    if (source == ImageSource.camera) {
        hasPermission = await requestCameraPermission();
    } else {
        // On newer Android/iOS photos permission is needed
        if(Platform.isAndroid || Platform.isIOS){
            hasPermission = await requestPhotosPermission();
        }
    }

    if (!hasPermission) {
        return PickedFileResult(type: PickedFileType.image, errorMessage: "Permission denied");
    }

    try {
        final XFile? pickedFile = await _picker.pickImage(source: source);
        if (pickedFile != null) {
            return PickedFileResult(file: File(pickedFile.path), path: pickedFile.path, type: PickedFileType.image);
        } else {
            return PickedFileResult(type: PickedFileType.image, errorMessage: "Image picking cancelled");
        }
    } catch (e) {
        debugPrint("Error picking image: $e");
        return PickedFileResult(type: PickedFileType.image, errorMessage: "Error picking image: $e");
    }
  }

  // --- Generic File Picking (Optional - requires file_picker package) ---
  /*
  Future<PickedFileResult> pickGeneralFile() async {
    // Handle permissions if needed (e.g., storage on older Android)
    // bool hasPermission = await _requestPermission(Permission.storage);
    // if (!hasPermission) {
    //   return PickedFileResult(type: PickedFileType.other, errorMessage: "Storage Permission denied");
    // }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null && result.files.single.path != null) {
        return PickedFileResult(file: File(result.files.single.path!), path: result.files.single.path!, type: PickedFileType.other);
      } else {
        // User canceled the picker
        return PickedFileResult(type: PickedFileType.other, errorMessage: "File picking cancelled");
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      return PickedFileResult(type: PickedFileType.other, errorMessage: "Error picking file: $e");
    }
  }
  */


  // --- Audio Recording ---

  Future<bool> startRecording() async {
    final hasPermission = await requestMicrophonePermission();
    if (!hasPermission) {
        debugPrint("Microphone permission denied");
        return false;
    }

    try {
       final Directory tempDir = await getTemporaryDirectory();
       final timestamp = DateTime.now().millisecondsSinceEpoch;
       _currentRecordingPath = p.join(tempDir.path, 'recording_$timestamp.m4a'); // Use m4a or similar supported format

       // Ensure the directory exists
       final dir = Directory(p.dirname(_currentRecordingPath!));
       if (!await dir.exists()) {
           await dir.create(recursive: true);
       }

       // Check if recorder is available
       if (await _audioRecorder.hasPermission()){ // Double check permission via recorder instance
           // Use recommended AAC LC encoder for broad compatibility
           const encoder = AudioEncoder.aacLc;
           const config = RecordConfig(encoder: encoder, autoGain: true);

           debugPrint("Starting recording to: $_currentRecordingPath");
           await _audioRecorder.start(config, path: _currentRecordingPath!);
           return true;
       } else {
           debugPrint("Audio recorder does not have permission or is unavailable.");
           _currentRecordingPath = null; // Clear path if failed
           return false;
       }

    } catch (e) {
       debugPrint("Error starting recording: $e");
       _currentRecordingPath = null; // Clear path if failed
       return false;
    }
  }

  Future<PickedFileResult> stopRecording() async {
    if (!await _audioRecorder.isRecording()) {
        return PickedFileResult(type: PickedFileType.audio, errorMessage: "Not recording");
    }
    try {
        final String? path = await _audioRecorder.stop();
        debugPrint("Recording stopped. File saved at: $path");
        // Use the path assigned during start, as stop() might return null sometimes (?)
        final finalPath = path ?? _currentRecordingPath;

        if (finalPath != null && await File(finalPath).exists()) {
            final result = PickedFileResult(file: File(finalPath), path: finalPath, type: PickedFileType.audio);
             _currentRecordingPath = null; // Clear after successful stop
             return result;
        } else {
            debugPrint("Error: Recording path is null or file doesn't exist after stop.");
            _currentRecordingPath = null; // Clear path
            return PickedFileResult(type: PickedFileType.audio, errorMessage: "Failed to save recording file.");
        }
    } catch (e) {
        debugPrint("Error stopping recording: $e");
        _currentRecordingPath = null; // Clear path
        return PickedFileResult(type: PickedFileType.audio, errorMessage: "Error stopping recording: $e");
    }
  }

  Future<bool> isRecording() async {
     return await _audioRecorder.isRecording();
  }

  void disposeRecorder() {
      // Important to release resources
      _audioRecorder.dispose();
  }
}