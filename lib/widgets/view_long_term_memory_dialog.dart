// lib/widgets/view_long_term_memory_dialog.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/long_term_memory_service.dart';

class ViewLongTermMemoryDialog extends StatefulWidget {
  const ViewLongTermMemoryDialog({super.key});

  @override
  State<ViewLongTermMemoryDialog> createState() => _ViewLongTermMemoryDialogState();
}

class _ViewLongTermMemoryDialogState extends State<ViewLongTermMemoryDialog> {

  void _showAddEditMemoryItemDialog({MemoryItem? itemToEdit}) {
    final isEditing = itemToEdit != null;
    final keyController = TextEditingController(text: itemToEdit?.key ?? '');
    final contentController = TextEditingController(text: itemToEdit?.content ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing ? 'Edit Memory Item' : 'Add Memory Item'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: keyController,
                  decoration: const InputDecoration(labelText: 'Key / Topic'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Key cannot be empty' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: contentController,
                  decoration: const InputDecoration(labelText: 'Content / Value'),
                  maxLines: 5,
                  minLines: 2,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Content cannot be empty' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          if (isEditing)
             TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                 // Confirm Deletion
                 showDialog(
                    context: context, // Use outer context for deletion confirmation
                    builder: (confirmCtx) => AlertDialog(
                      title: Text('Confirm Delete'),
                      content: Text('Delete memory item with key "${itemToEdit.key}"?'),
                      actions: [
                         TextButton(onPressed: ()=> Navigator.of(confirmCtx).pop(), child: Text('Cancel')),
                         TextButton(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: (){
                               final memoryService = Provider.of<LongTermMemoryService>(context, listen: false);
                               memoryService.deleteMemoryItemById(itemToEdit.id);
                               Navigator.of(confirmCtx).pop(); // Close confirm
                               Navigator.of(ctx).pop(); // Close add/edit
                            },
                            child: Text('Delete')
                         )
                      ]
                    )
                 );
              },
              child: const Text('Delete'),
            ),
          ElevatedButton(
            child: Text(isEditing ? 'Save Changes' : 'Add'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                 final memoryService = Provider.of<LongTermMemoryService>(context, listen: false);
                 if (isEditing) {
                   final updatedItem = MemoryItem(
                      id: itemToEdit.id,
                      key: keyController.text.trim(),
                      content: contentController.text.trim(),
                      timestamp: itemToEdit.timestamp, // Keep original timestamp or update? Decide here. Let's update.
                   );
                   // Update timestamp on edit
                    updatedItem.timestamp = DateTime.now();
                   memoryService.updateMemoryItem(updatedItem);

                 } else {
                   memoryService.addMemoryManually(
                      keyController.text.trim(), contentController.text.trim());
                 }
                 Navigator.of(ctx).pop();
              }
            },
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    // Use Consumer to rebuild when memory changes
    return Consumer<LongTermMemoryService>(
      builder: (context, memoryService, child) {
        final items = memoryService.memoryItems;

        return AlertDialog(
          title: const Text('Long-Term Memory Store'),
          content: SizedBox(
            width: double.maxFinite, // Use available width
            height: MediaQuery.of(context).size.height * 0.6, // Fixed height
            child: items.isEmpty
                ? const Center(child: Text('No memory items saved yet.'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text(item.key, style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                             item.content,
                             maxLines: 2,
                             overflow: TextOverflow.ellipsis,
                           ),
                          trailing: Text(
                             item.timestamp.toLocal().toString().substring(0, 10), // Just date
                             style: Theme.of(context).textTheme.bodySmall,
                           ),
                          onTap: () => _showAddEditMemoryItemDialog(itemToEdit: item),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
             TextButton(
                child: const Text('Add Manually'),
                onPressed: () => _showAddEditMemoryItemDialog(),
              ),
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}