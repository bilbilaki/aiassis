// lib/services/custom_tool_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const _customToolsKey = 'custom_function_tools';
var _uuid = Uuid();

// Represents the data structure for storing a custom tool persistently
class CustomToolData {
  final String id;
  String name;
  String description;
  String schemaJson; // Store schema as JSON string

  CustomToolData({
    required this.id,
    required this.name,
    required this.description,
    required this.schemaJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'schemaJson': schemaJson,
      };

  factory CustomToolData.fromJson(Map<String, dynamic> json) => CustomToolData(
        id: json['id'] ?? _uuid.v4(), // Assign new ID if missing
        name: json['name'] ?? 'Untitled Tool',
        description: json['description'] ?? '',
        schemaJson: json['schemaJson'] ?? '{}', // Default to empty JSON object
      );

  // Attempt to convert the stored JSON string into a FunctionDeclaration
  FunctionDeclaration? toFunctionDeclaration() {
    try {
      final schemaMap = jsonDecode(schemaJson);
      if (schemaMap is Map<String, dynamic>) {
        // Basic validation/parsing - needs improvement for real scenarios
        final typeString = schemaMap['type'] as String?;
         final propertiesMap = schemaMap['properties'] as Map<String, dynamic>?;
         final requiredList = (schemaMap['required'] as List<dynamic>?)?.map((e) => e.toString()).toList();
         final itemsMap = schemaMap['items'] as Map<String, dynamic>?; // For arrays

        SchemaType schemaType;
        // Very basic type mapping - enhance as needed
        switch(typeString?.toUpperCase()) {
            case 'OBJECT': schemaType = SchemaType.object; break;
            case 'ARRAY': schemaType = SchemaType.array; break;
            case 'STRING': schemaType = SchemaType.string; break;
            case 'NUMBER': schemaType = SchemaType.number; break;
            case 'INTEGER': schemaType = SchemaType.integer; break;
            case 'BOOLEAN': schemaType = SchemaType.boolean; break;
            default: schemaType = SchemaType.object; // Default or throw error?
        }

        // Recursive schema parsing is complex. This is a simplified version.
        // It assumes properties are simple types for now.
        Map<String, Schema>? properties;
        if (propertiesMap != null) {
            properties = propertiesMap.map((key, value) {
                 // TODO: Recursively parse nested schemas if needed
                SchemaType propType = SchemaType.string; // Default
                String? propTypeStr = (value as Map<String,dynamic>?)?['type']?.toString().toUpperCase();
                 switch(propTypeStr) {
                    case 'STRING': propType = SchemaType.string; break;
                    case 'NUMBER': propType = SchemaType.number; break;
                    case 'INTEGER': propType = SchemaType.integer; break;
                    case 'BOOLEAN': propType = SchemaType.boolean; break;
                    // Add array, object etc. if needed
                 }
                return MapEntry(key, Schema(propType, description: (value)?['description']?.toString()));
            });
        }

        Schema? itemsSchema;
         if (itemsMap != null && schemaType == SchemaType.array){
            // TODO: Parse items schema similarly to properties
             itemsSchema = Schema(SchemaType.string); // Placeholder
         }


        return FunctionDeclaration(
          name,
          description,
          Schema(
            schemaType,
            properties: properties,
            requiredProperties: requiredList,
            items: itemsSchema, // Add if type is array
            // description: schemaMap['description'] // Top-level schema description
          ),
        );
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("Error parsing tool '$name' schema: $e");
        print("Schema JSON was: $schemaJson");
      }
      return null; // Return null if parsing fails
    }
  }
}

class CustomToolService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<CustomToolData> _customTools = [];

  List<CustomToolData> get customTools => _customTools;

  // Provides the list of valid FunctionDeclarations for the Gemini model
  List<FunctionDeclaration> get functionDeclarations {
    return _customTools
        .map((data) => data.toFunctionDeclaration())
        .where((decl) => decl != null) // Filter out tools with invalid schemas
        .cast<FunctionDeclaration>()
        .toList();
  }

  CustomToolService() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await loadTools();
  }

  Future<void> loadTools() async {
    if (_prefs == null) await _init();
    final String? toolsJson = _prefs!.getString(_customToolsKey);
    if (toolsJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(toolsJson);
        _customTools = decodedList
            .map((item) => CustomToolData.fromJson(item as Map<String, dynamic>))
            .toList();
      } catch (e) {
         if (kDebugMode) {
           print("Error loading custom tools: $e");
         }
        _customTools = [];
      }
    } else {
      _customTools = [];
    }
    notifyListeners();
  }

  Future<void> _saveTools() async {
    if (_prefs == null) return;
    final String toolsJson = jsonEncode(_customTools.map((e) => e.toJson()).toList());
    await _prefs!.setString(_customToolsKey, toolsJson);
    notifyListeners(); // Crucial: Notify after any change
  }

  Future<void> addTool(String name, String description, String schemaJson) async {
     if (name.isEmpty || description.isEmpty) return; // Basic validation
      // Add basic JSON validation if possible before adding
      try {
        jsonDecode(schemaJson); // Test if it's valid JSON
      } catch (_) {
        // Optionally show an error to the user
        print("Invalid Schema JSON provided for tool '$name'");
        return;
      }

      final newTool = CustomToolData(
        id: _uuid.v4(),
        name: name,
        description: description,
        schemaJson: schemaJson,
      );
      _customTools.add(newTool);
      await _saveTools();
  }

    Future<void> updateTool(CustomToolData toolToUpdate) async {
     if (toolToUpdate.name.isEmpty || toolToUpdate.description.isEmpty) return;
     try {
        jsonDecode(toolToUpdate.schemaJson); // Validate JSON
      } catch (_) {
         print("Invalid Schema JSON provided for updating tool '${toolToUpdate.name}'");
         return;
      }

     int index = _customTools.indexWhere((tool) => tool.id == toolToUpdate.id);
      if (index != -1) {
        _customTools[index] = toolToUpdate;
        await _saveTools();
     }
  }


  Future<void> deleteTool(String id) async {
    _customTools.removeWhere((tool) => tool.id == id);
    await _saveTools();
  }

  // --- Placeholder for actual tool execution logic ---
  // In a real app, this might call APIs, run local code, etc.
  // For now, it just returns a placeholder response.
  Future<Map<String, dynamic>> executeCustomTool(String toolName, Map<String, dynamic> args) async {
     if (kDebugMode) {
       print("--- Attempting to execute custom tool ---");
       print("Tool Name: $toolName");
       print("Arguments: $args");
       print("--- End Tool Execution Attempt ---");
     }

    // TODO: Implement actual logic for custom tools based on toolName
    // This is where you'd integrate with external APIs, local functions, etc.

    // Simulate execution with a generic success response
    await Future.delayed(Duration(milliseconds: 500)); // Simulate work
    return {'status': 'Success', 'message': 'Custom tool $toolName executed (simulated).', 'args_received': args};
  }

}