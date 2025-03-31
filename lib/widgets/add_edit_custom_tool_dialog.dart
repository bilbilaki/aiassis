// lib/widgets/add_edit_custom_tool_dialog.dart
import 'package:flutter/material.dart';
//import 'package:json_editor/json_editor.dart'; // Using json_editor
import 'package:provider/provider.dart';
import '../services/custom_tool_service.dart';
//import 'package:aiassis/pages/settings_page.dart';
//import 'package:aiassis/services/settings_service.dart';
import 'package:json_editor_flutter/json_editor_flutter.dart';

class AddEditCustomToolDialog extends StatefulWidget {
  final CustomToolData? editingTool; // Pass tool data if editing
  
  const AddEditCustomToolDialog({super.key, this.editingTool});

  @override
  State<AddEditCustomToolDialog> createState() => _AddEditCustomToolDialogState();
}

class _AddEditCustomToolDialogState extends State<AddEditCustomToolDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
late TextEditingController _descriptionController;
  late JsonEditor _schemaController; // Ensure JsonEditorController is defined and imported correctly

bool get _isEditing => widget.editingTool != null;

@override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.editingTool?.name ?? '');
    _descriptionController = TextEditingController(text: widget.editingTool?.description ?? '');
    // Initialize JsonEditorController with initial schema or empty object
    _schemaController = JsonEditor(
      json: widget.editingTool?.schemaJson ?? '{}', // Start with existing or empty JSON
      onChanged: (value) {},
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    //_schemaController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final toolService = Provider.of<CustomToolService>(context, listen: false);
      final schemaJsonString = _schemaController.json; // Get JSON string

      if (_isEditing) {
         // Create updated tool data object
        final updatedTool = CustomToolData(
          id: widget.editingTool!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          schemaJson: schemaJsonString,
        );
         toolService.updateTool(updatedTool);

      } else {
        // Add new tool
        toolService.addTool(
          _nameController.text.trim(),
          _descriptionController.text.trim(),
          schemaJsonString,
        );
      }
      Navigator.of(context).pop(); // Close dialog
    }
  }

   void _delete() {
    if (!_isEditing) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete the tool "${widget.editingTool!.name}"?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () {
              final toolService = Provider.of<CustomToolService>(context, listen: false);
              toolService.deleteTool(widget.editingTool!.id);
              Navigator.of(ctx).pop(); // Close confirmation dialog
              Navigator.of(context).pop(); // Close edit dialog
            },
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Custom Tool' : 'Add Custom Tool'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView( // Allow content to scroll if needed
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tool Name'),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Name cannot be empty' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                 maxLines: 3,
                 minLines: 1,
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Description cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              const Text('Schema (JSON Format):', style: TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Container(
                 height: 200, // Give the JSON editor a fixed height
                 decoration: BoxDecoration(
                   border: Border.all(color: Colors.grey),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 // Using JsonEditor widget
                 child: JsonEditor(
                    json: widget.editingTool?.schemaJson ?? '{}', // Start with existing or empty JSON
                    onChanged: (value) {},
                    // Optional configurations for the editor:
                    // jsonEditorTheme: JsonEditorTheme(...)
                    // Key/Value style customizations if needed
                 ),
               ),
              // Basic Schema Example Hint
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Example Schema: {"type": "OBJECT", "properties": {"location": {"type": "STRING", "description": "City and state"}}, "required": ["location"]}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (_isEditing)
           TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: _delete,
            child: const Text('Delete'),
          ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Save Changes' : 'Add Tool'),
        ),
      ],
    );
  }
}