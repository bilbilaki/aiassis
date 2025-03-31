// lib/pages/settings_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/custom_tool_service.dart';
import '../widgets/add_edit_custom_tool_dialog.dart';
import '../widgets/view_long_term_memory_dialog.dart';

class SettingsPage extends StatelessWidget {
 const SettingsPage({super.key});

 @override
 Widget build(BuildContext context) {
 final settings = context.watch<SettingsService>();
 final toolService = context.watch<CustomToolService>();

 return Scaffold(
 appBar: AppBar(
 title: const Text('Settings'),
 actions: [
 IconButton(
 icon: const Icon(Icons.refresh),
 tooltip: 'Reset to Defaults',
 onPressed: () async {
 final confirm = await showDialog<bool>(
 context: context,
 builder: (ctx) => AlertDialog(
 title: const Text('Reset Settings?'),
 content: const Text('This will reset all generation parameters, system instruction, buffer size, and theme to their defaults. Custom tools and long-term memory will not be affected.'), // Updated text
 actions: [
 TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
 TextButton(
 style: TextButton.styleFrom(foregroundColor: Colors.orange),
 onPressed: () => Navigator.of(ctx).pop(true),
 child: const Text('Reset'),
 ),
 ],
 ),
 );
 if (confirm == true) {
 context.read<SettingsService>().resetToDefaults();
 ScaffoldMessenger.of(context).showSnackBar(
 const SnackBar(content: Text('Settings reset to defaults.'))
 );
 }
 },
 )
 ],
 ),
 body: ListView(
 padding: const EdgeInsets.all(16.0),
 children: [
 // --- Theme Settings --- <-- ADD THIS SECTION
 Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
 RadioListTile<ThemeMode>(
 title: const Text('System Default'),
 subtitle: const Text('Follow device theme setting'),
 value: ThemeMode.system,
 groupValue: settings.themeMode,
 onChanged: (value) => settings.setThemeMode(value ?? ThemeMode.system),
 ),
 RadioListTile<ThemeMode>(
 title: const Text('Light Theme'),
 value: ThemeMode.light,
 groupValue: settings.themeMode,
 onChanged: (value) => settings.setThemeMode(value ?? ThemeMode.light),
 ),
 RadioListTile<ThemeMode>(
 title: const Text('Dark Theme'),
 value: ThemeMode.dark,
 groupValue: settings.themeMode,
 onChanged: (value) => settings.setThemeMode(value ?? ThemeMode.dark),
 ),


 const Divider(height: 32),


 // --- Generation Parameters --- (Keep as before)
 Text('Generation Parameters', style: Theme.of(context).textTheme.titleLarge),
 // ... sliders and inputs for temp, topk, topp, max tokens ...
 _buildSliderSetting(
  context,
  label: 'Temperature: ${settings.temperature.toStringAsFixed(2)}',
  value: settings.temperature,
  min: 0.0, max: 2.0, divisions: 20,
  onChanged: (val) => settings.setTemperature(val),
 ),
 _buildIntInputSetting(
  context,
  label: 'Top K:',
  value: settings.topK,
  onChanged: (val) => settings.setTopK(val),
  minValue: 1
 ),
 _buildSliderSetting(
  context,
  label: 'Top P: ${settings.topP.toStringAsFixed(2)}',
  value: settings.topP,
  min: 0.0, max: 1.0, divisions: 20,
  onChanged: (val) => settings.setTopP(val),
 ),
 _buildIntInputSetting(
  context,
  label: 'Max Output Tokens:',
  value: settings.maxOutputTokens,
  onChanged: (val) => settings.setMaxOutputTokens(val),
  minValue: 1
 ),



 const Divider(height: 32),


 // --- Message Buffer --- (Keep as before)
 Text('Chat History Buffer', style: Theme.of(context).textTheme.titleLarge),
 // ... input for buffer size ...
 _buildIntInputSetting(
  context,
  label: 'Messages to Remember (0=None):',
  value: settings.messageBufferSize,
  onChanged: (val) => settings.setMessageBufferSize(val),
  minValue: 0,
  maxValue: 50 // Match service limit
 ),



 const Divider(height: 32),


 // --- System Instruction --- (Keep as before)
 Text('System Instruction', style: Theme.of(context).textTheme.titleLarge),
 // ... text field ...
 TextField(
  controller: TextEditingController(text: settings.systemInstruction)..selection = TextSelection.fromPosition(TextPosition(offset: settings.systemInstruction.length)),
  decoration: const InputDecoration(
  border: OutlineInputBorder(),
  hintText: 'Enter system instruction for the AI...',
  ),
  maxLines: 6,
  minLines: 3,
  onChanged: (val) => settings.setSystemInstruction(val),
 ),



 const Divider(height: 32),


 // --- Long-Term Memory --- (Keep as before)
 ListTile(
 leading: const Icon(Icons.memory),
 title: Text('Long-Term Memory', style: Theme.of(context).textTheme.titleLarge),
 // ... rest of LTM ListTile ...
 subtitle: const Text('View or manually edit saved items.'),
 trailing: const Icon(Icons.arrow_forward_ios),
 onTap: () {
  showDialog(
  context: context,
  builder: (_) => const ViewLongTermMemoryDialog(),
  );
 },
 ),



 const Divider(height: 32),


 // --- Custom Tools --- (Keep as before)
 Row(
 mainAxisAlignment: MainAxisAlignment.spaceBetween,
 children: [
 Text('Custom Function Tools', style: Theme.of(context).textTheme.titleLarge),
 // ... Add Tool IconButton ...
 IconButton(
  icon: const Icon(Icons.add_circle),
  tooltip: 'Add Custom Tool',
  color: Theme.of(context).colorScheme.primary, // Use theme color
  onPressed: () {
  showDialog(
  context: context,
  builder: (_) => const AddEditCustomToolDialog(), // Pass null for adding
  );
  },
 ),
 ],
 ),
 // ... Custom Tools ListView ...
 const SizedBox(height: 8),
 toolService.customTools.isEmpty
  ? const Center(child: Text('No custom tools defined.'))
  : ListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  itemCount: toolService.customTools.length,
  itemBuilder: (context, index) {
  final tool = toolService.customTools[index];
  final declaration = tool.toFunctionDeclaration();
  final bool isSchemaValid = declaration != null;

  return Card(
  margin: const EdgeInsets.symmetric(vertical: 4),
  child: ListTile(
  leading: Icon(Icons.build_circle_outlined, color: isSchemaValid ? Colors.green : Colors.orange),
  title: Text(tool.name),
  subtitle: Text(tool.description, maxLines: 1, overflow: TextOverflow.ellipsis),
  trailing: isSchemaValid ? null : Tooltip(message: 'Schema Error', child: Icon(Icons.warning_amber_rounded, color: Colors.orange)),
  onTap: () {
  showDialog(
  context: context,
  builder: (_) => AddEditCustomToolDialog(editingTool: tool),
  );
  },
  ),
  );
  },
 ),


 ],
 ),
 );
 }

 // --- Helper Methods (_buildSliderSetting, _buildIntInputSetting) --- (Keep as before)
 Widget _buildSliderSetting(BuildContext context, {
 required String label,
 required double value,
 required double min,
 required double max,
 required int divisions,
 required ValueChanged<double> onChanged,
 }) {
 // ... implementation ...
 return Row(
  children: [
  Expanded(flex: 2, child: Text(label)), // Give label more space
  Expanded(
  flex: 3, // Give slider more space
  child: Slider(
  value: value,
  min: min,
  max: max,
  divisions: divisions,
  label: value.toStringAsFixed(2),
  onChanged: onChanged,
  ),
  ),
  ],
 );
 }

 Widget _buildIntInputSetting(BuildContext context, {
 required String label,
 required int value,
 required ValueChanged<int> onChanged,
 int minValue = 0,
 int? maxValue,
 }) {
 // ... implementation ...
 final controller = TextEditingController(text: value.toString());
 controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));

 return Row(
  children: [
  Expanded(child: Text(label)),
  SizedBox(
  width: 80,
  child: TextFormField(
  controller: controller,
  keyboardType: TextInputType.number,
  textAlign: TextAlign.right,
  decoration: InputDecoration(isDense: true),
  onFieldSubmitted: (newValue) {
  final intVal = int.tryParse(newValue);
  if (intVal != null) {
  int finalVal = intVal;
  if(finalVal < minValue) finalVal = minValue;
  if(maxValue != null && finalVal > maxValue) finalVal = maxValue;
  onChanged(finalVal);
  if (finalVal != intVal) {
  controller.text = finalVal.toString();
  controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
  }
  } else {
  controller.text = value.toString();
  controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
  }
  },
  ),
  ),
  ],
 );
 }
}