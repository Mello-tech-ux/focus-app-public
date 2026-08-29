import 'package:flutter/material.dart';

import '../models/study_module.dart';

class ModulesScreen extends StatefulWidget {
  const ModulesScreen({super.key, required this.initialModules});

  final List<StudyModule> initialModules;

  @override
  State<ModulesScreen> createState() => _ModulesScreenState();
}

class _ModulesScreenState extends State<ModulesScreen> {
  late List<StudyModule> _modules;

  @override
  void initState() {
    super.initState();
    // The home screen owns this in-memory list for this first version.
    // Keeping the same reference also preserves changes when the browser back
    // button is used instead of the app-bar back action.
    _modules = widget.initialModules;
  }

  Future<void> _showModuleForm([StudyModule? module]) async {
    final result = await showModalBottomSheet<StudyModule>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ModuleFormSheet(module: module),
    );
    if (result == null || !mounted) return;

    setState(() {
      final index = _modules.indexWhere((item) => item.id == result.id);
      if (index == -1) {
        _modules.add(result);
      } else {
        _modules[index] = result;
      }
    });
  }

  Future<void> _deleteModule(StudyModule module) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${module.name}?'),
        content: const Text('This module will be removed from your study plan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete == true && mounted) {
      setState(() => _modules.removeWhere((item) => item.id == module.id));
    }
  }

  void _close() => Navigator.of(context).pop(_modules);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _close,
        ),
        title: const Text('My Modules'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showModuleForm,
        icon: const Icon(Icons.add),
        label: const Text('Add module'),
      ),
      body: _modules.isEmpty
          ? const _EmptyModules()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              itemCount: _modules.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final module = _modules[index];
                return _ModuleCard(
                  module: module,
                  onEdit: () => _showModuleForm(module),
                  onDelete: () => _deleteModule(module),
                );
              },
            ),
    );
  }
}

class _EmptyModules extends StatelessWidget {
  const _EmptyModules();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined, size: 56, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'Start with your modules',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add the subjects you are taking. You can set a study target now or leave it for later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.onEdit,
    required this.onDelete,
  });

  final StudyModule module;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Row(
          children: [
            Container(width: 7, height: 156, color: module.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 8, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            module.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        PopupMenuButton<_ModuleMenuAction>(
                          tooltip: 'Module options',
                          onSelected: (action) {
                            if (action == _ModuleMenuAction.edit) onEdit();
                            if (action == _ModuleMenuAction.delete) onDelete();
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _ModuleMenuAction.edit,
                              child: Text('Edit'),
                            ),
                            PopupMenuItem(
                              value: _ModuleMenuAction.delete,
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (module.code != null && module.code!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          module.code!,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                      ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoPill(label: module.difficulty.label),
                        _InfoPill(label: '${module.priority.label} priority'),
                        if (module.weeklyStudyTargetHours != null)
                          _InfoPill(
                            label: '${_formatHours(module.weeklyStudyTargetHours!)} h / week',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ModuleMenuAction { edit, delete }

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colors.onSecondaryContainer,
              ),
        ),
      ),
    );
  }
}

class _ModuleFormSheet extends StatefulWidget {
  const _ModuleFormSheet({this.module});

  final StudyModule? module;

  @override
  State<_ModuleFormSheet> createState() => _ModuleFormSheetState();
}

class _ModuleFormSheetState extends State<_ModuleFormSheet> {
  static const _colors = [
    Color(0xFF315E51),
    Color(0xFF3B6499),
    Color(0xFF8C5538),
    Color(0xFF87536E),
    Color(0xFF5D6B32),
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _targetController;
  late ModuleDifficulty _difficulty;
  late ModulePriority _priority;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    final module = widget.module;
    _nameController = TextEditingController(text: module?.name);
    _codeController = TextEditingController(text: module?.code);
    _targetController = TextEditingController(
      text: module?.weeklyStudyTargetHours == null
          ? ''
          : _formatHours(module!.weeklyStudyTargetHours!),
    );
    _difficulty = module?.difficulty ?? ModuleDifficulty.moderate;
    _priority = module?.priority ?? ModulePriority.normal;
    _selectedColor = module?.color ?? _colors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final targetText = _targetController.text.trim().replaceAll(',', '.');
    final target = targetText.isEmpty ? null : double.parse(targetText);
    final existing = widget.module;
    final module = StudyModule(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      code: _codeController.text.trim().isEmpty ? null : _codeController.text.trim(),
      difficulty: _difficulty,
      priority: _priority,
      weeklyStudyTargetHours: target,
      color: _selectedColor,
    );
    Navigator.of(context).pop(module);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.module != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditing ? 'Edit module' : 'Add a module',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Module name',
                    hintText: 'e.g. Calculus 1',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a module name.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Module code (optional)',
                    hintText: 'e.g. MAT101',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ModuleDifficulty>(
                  value: _difficulty,
                  decoration: const InputDecoration(
                    labelText: 'Difficulty',
                    border: OutlineInputBorder(),
                  ),
                  items: ModuleDifficulty.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _difficulty = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ModulePriority>(
                  value: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                  ),
                  items: ModulePriority.values
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _priority = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _targetController,
                  decoration: const InputDecoration(
                    labelText: 'Weekly study target (optional)',
                    hintText: 'Hours per week, e.g. 4',
                    suffixText: 'hours',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final hours = double.tryParse(value.trim().replaceAll(',', '.'));
                    return hours == null || hours <= 0
                        ? 'Enter a number greater than 0, or leave it blank.'
                        : null;
                  },
                ),
                const SizedBox(height: 20),
                Text('Module color', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  children: _colors
                      .map(
                        (color) => Semantics(
                          label: 'Select module color',
                          selected: color == _selectedColor,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () => setState(() => _selectedColor = color),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: color == _selectedColor
                                    ? Border.all(
                                        color: Theme.of(context).colorScheme.onSurface,
                                        width: 3,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(isEditing ? 'Save changes' : 'Add module'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatHours(double hours) =>
    hours == hours.roundToDouble() ? hours.toInt().toString() : hours.toString();
