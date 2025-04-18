// lib/services/custom_tool_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:json_schema/json_schema.dart'
    as json_schema; // Use prefix for json_schema
import '../constants.dart' as constants; // Use constants

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

  FunctionDeclaration? toFunctionDeclaration() {
    try {
      final schemaMap = jsonDecode(schemaJson);
      if (schemaMap is Map<String, dynamic>) {
        // Helper to parse SchemaType safely
        SchemaType parseSchemaType(String? typeString) {
          switch (typeString?.toUpperCase()) {
            case 'OBJECT':
              return SchemaType.object;
            case 'ARRAY':
              return SchemaType.array;
            case 'STRING':
              return SchemaType.string;
            case 'NUMBER':
              return SchemaType.number;
            case 'INTEGER':
              return SchemaType.integer;
            case 'BOOLEAN':
              return SchemaType.boolean;
            default:
              if (kDebugMode)
                print(
                  "Warning: Unknown schema type '$typeString' for tool '$name'. Defaulting to STRING.",
                );
              return SchemaType.string;
          }
        }

        // Helper to parse individual property schemas (basic)
        Schema parsePropertySchema(dynamic propValue) {
          if (propValue is Map<String, dynamic>) {
            final propType = parseSchemaType(propValue['type'] as String?);
            final propDesc = propValue['description'] as String?;
            final propEnum =
                (propValue['enum'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList();
            return Schema(
              propType,
              description: propDesc,
              enumValues: propEnum,
            );
          }
          if (kDebugMode)
            print(
              "Warning: Malformed property schema for tool '$name': $propValue. Defaulting to STRING.",
            );
          return Schema(SchemaType.string);
        }

        final schemaType = parseSchemaType(schemaMap['type'] as String?);
        final propertiesMap = schemaMap['properties'] as Map<String, dynamic>?;
        final requiredList =
            (schemaMap['required'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList();

        Map<String, Schema>? properties;
        if (propertiesMap != null) {
          properties = propertiesMap.map(
            (key, value) => MapEntry(key, parsePropertySchema(value)),
          );
        }

        return FunctionDeclaration(
          name,
          description,
          Schema(
            schemaType,
            properties: properties,
            requiredProperties: requiredList,
            description: schemaMap['description'] as String?,
          ),
        );
      }
      return null;
    } catch (e, s) {
      if (kDebugMode) {
        print("Error parsing tool '$name' schema to FunctionDeclaration: $e");
        print("Stack trace: $s");
        print("Schema JSON was: $schemaJson");
      }
      return null;
    }
  }
}

class CustomToolService with ChangeNotifier {
  SharedPreferences? _prefs;
  List<CustomToolData> _customTools = [];

  List<CustomToolData> get customTools => _customTools;

  List<FunctionDeclaration> get functionDeclarations {
    return _customTools
        .map((data) => data.toFunctionDeclaration())
        .where((decl) => decl != null)
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
    final String? toolsJson = _prefs!.getString(constants.prefsCustomToolsKey);
    if (toolsJson != null) {
      try {
        final List<dynamic> decodedList = jsonDecode(toolsJson);
        _customTools =
            decodedList
                .map(
                  (item) =>
                      CustomToolData.fromJson(item as Map<String, dynamic>),
                )
                .toList();
      } catch (e, s) {
        if (kDebugMode) {
          print("Error loading/decoding custom tools: $e");
          print("Stack trace: $s");
          print("Corrupted JSON string: $toolsJson");
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
    final String toolsJson = jsonEncode(
      _customTools.map((e) => e.toJson()).toList(),
    );
    await _prefs!.setString(constants.prefsCustomToolsKey, toolsJson);
    notifyListeners();
  }

  Future<bool> _validateSchemaJson(String schemaJson, String toolName) async {
    try {
      final decodedSchema = jsonDecode(schemaJson);
      if (decodedSchema is! Map<String, dynamic>) {
        print(
          "Validation Error for '$toolName': Schema JSON must be a JSON object (Map).",
        );
        return false;
      }
      final schema = json_schema.JsonSchema.create(decodedSchema);
      var validationResult = schema.validate(decodedSchema);
      if (!validationResult.isValid) {
        print(
          "Validation Error for '$toolName': Schema is invalid according to OpenAPI spec.",
        );
        validationResult.errors.forEach(
          (error) => print(" - ${error.message} at ${error.instancePath}"),
        );
        return false;
      }
      print("Schema for '$toolName' validated successfully.");
      return true;
    } catch (e) {
      print(
        "Validation Error for '$toolName': Invalid JSON format or schema structure: $e",
      );
      return false;
    }
  }

  Future<bool> addTool(
    String name,
    String description,
    String schemaJson,
  ) async {
    if (name.isEmpty || description.isEmpty) {
      print("Error adding tool: Name and description cannot be empty.");
      return false;
    }
    if (!await _validateSchemaJson(schemaJson, name)) {
      return false;
    }

    final newTool = CustomToolData(
      id: _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      schemaJson: schemaJson,
    );
    _customTools.add(newTool);
    await _saveTools();
    return true;
  }

  Future<bool> updateTool(CustomToolData toolToUpdate) async {
    if (toolToUpdate.name.isEmpty || toolToUpdate.description.isEmpty) {
      print("Error updating tool: Name and description cannot be empty.");
      return false;
    }
    if (!await _validateSchemaJson(
      toolToUpdate.schemaJson,
      toolToUpdate.name,
    )) {
      return false;
    }

    int index = _customTools.indexWhere((tool) => tool.id == toolToUpdate.id);
    if (index != -1) {
      _customTools[index] = toolToUpdate;
      await _saveTools();
      return true;
    } else {
      print("Error updating tool: Tool with ID ${toolToUpdate.id} not found.");
      return false;
    }
  }

  Future<void> deleteTool(String id) async {
    _customTools.removeWhere((tool) => tool.id == id);
    await _saveTools();
  }

  Future<Map<String, dynamic>> executeCustomTool(
    String toolName,
    Map<String, dynamic> args,
  ) async {
    if (kDebugMode) {
      print("--- Executing Custom Tool ---");
      print("Tool Name: $toolName");
      print("Arguments: $args");
    }

    try {
      switch (toolName) {
        case 'get_current_weather':
          return await _executeGetWeather(args);

        case 'send_simple_email':
          return await _executeSendEmail(args);

        default:
          print("Error: Attempted to execute unknown custom tool '$toolName'");
          return {
            'status': 'Error',
            'message': "The custom tool '$toolName' is not implemented.",
          };
      }
    } catch (e, s) {
      print("Critical Error during custom tool execution '$toolName': $e");
      print("Stack Trace: $s");
      return {
        'status': 'Error',
        'message':
            "An unexpected error occurred while executing the tool '$toolName'.",
      };
    } finally {
      if (kDebugMode) print("--- Finished Custom Tool Execution ---");
    }
  }

  Future<Map<String, dynamic>> _executeGetWeather(
    Map<String, dynamic> args,
  ) async {
    final location = args['location'] as String?;
    final unit = args['unit'] as String? ?? 'celsius';

    if (location == null || location.isEmpty) {
      return {
        'status': 'Error',
        'message':
            "Missing required argument 'location' for get_current_weather.",
      };
    }

    try {
      print("Simulating weather API call for location: $location, unit: $unit");
      await Future.delayed(Duration(seconds: 1));

      final weatherData = {
        'location': location,
        'temperature': unit == 'celsius' ? 25 : 77,
        'unit': unit,
        'condition': 'Sunny',
        'humidity': '60%',
      };
      return {'status': 'Success', 'data': weatherData};
    } catch (e) {
      print("Error calling weather API: $e");
      return {
        'status': 'Error',
        'message': "Failed to retrieve weather for '$location'.",
      };
    }
  }

  Future<Map<String, dynamic>> _executeSendEmail(
    Map<String, dynamic> args,
  ) async {
    final recipient = args['recipient'] as String?;
    final subject = args['subject'] as String?;
    final body = args['body'] as String?;

    if (recipient == null || subject == null || body == null) {
      return {
        'status': 'Error',
        'message':
            'Missing required arguments (recipient, subject, body) for send_simple_email.',
      };
    }

    try {
      print("Simulating sending email to: $recipient, Subject: $subject");
      await Future.delayed(Duration(milliseconds: 500));

      return {
        'status': 'Success',
        'data': 'Email queued for sending to $recipient.',
      };
    } catch (e) {
      print("Error sending email: $e");
      return {
        'status': 'Error',
        'message': 'Failed to send email to $recipient.',
      };
    }
  }
}
