// lib/services/ai_helper_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AiHelperService {
  final String _openaiApiKey;
  final String _openaiTranscriptionUrl = 'https://api.avalai.ir/v1/audio/transcriptions';

  // Constructor requires OpenAI API Key
  AiHelperService({required String openaiApiKey}) : _openaiApiKey = openaiApiKey = 'aa-UYSYGB3RR5enQDwXZUqXfQEiwlq9SdR38KKOBlbIwgM158VG';


  Future<String?> transcribeAudio(String filePath) async {
    if (_openaiApiKey.isEmpty) {
        debugPrint("OpenAI API Key is missing. Cannot transcribe.");
        return Future.value("Error: OpenAI API Key not configured."); // Return error string
    }

    try {
        File audioFile = File(filePath);
        if (!await audioFile.exists()) {
            return Future.value("Error: Audio file not found at $filePath");
        }

        var request = http.MultipartRequest('POST', Uri.parse(_openaiTranscriptionUrl));

        // Headers
        request.headers['Authorization'] = 'Bearer $_openaiApiKey';
        // request.headers['Content-Type'] is set automatically for multipart

        // Model field
        request.fields['model'] = 'whisper-1'; // Use the desired Whisper model

        // File field
        request.files.add(await http.MultipartFile.fromPath(
            'file', // Expected field name by the API
            filePath,
            // You might need to specify filename and content type depending on the API requirements
            // filename: filePath.split('/').last,
            // contentType: MediaType('audio', 'm4a'), // Adjust based on actual audio format
        ));


        debugPrint("Sending audio transcription request to OpenAI...");
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);
        debugPrint("OpenAI Transcription Response Status: ${response.statusCode}");
        // debugPrint("OpenAI Transcription Response Body: ${response.body}");


        if (response.statusCode == 200) {
            var decodedBody = jsonDecode(response.body);
            return decodedBody['text'] as String?;
        } else {
            debugPrint("OpenAI Transcription Error: ${response.body}");
            // Try to parse error message
            String errorMsg = "Error ${response.statusCode}";
            try {
                 var decodedError = jsonDecode(response.body);
                 if (decodedError['error'] != null && decodedError['error']['message'] != null){
                     errorMsg += ": ${decodedError['error']['message']}";
                 } else {
                     errorMsg += ": ${response.body}";
                 }
            } catch (_) {
                 errorMsg += ": ${response.body}"; // Fallback if error parsing fails
            }
            return Future.value("Transcription Error: $errorMsg"); // Return detailed error
        }
    } catch (e) {
        debugPrint("Exception during audio transcription: $e");
        return Future.value("Exception during transcription: $e"); // Return exception string
    }
  }
}