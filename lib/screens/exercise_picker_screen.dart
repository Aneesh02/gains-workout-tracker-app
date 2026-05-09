import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import 'create_exercise_sheet.dart';

class ExercisePickerScreen extends StatefulWidget {
  final int? replaceIndex;
  /// When true, tapping the confirm button pops with a List of Exercise
  /// instead of directly adding to the active workout.
  final bool returnMode;
  /// Exercise IDs already present in the active workout — shown grayed out.
  final Set<String> alreadyAddedIds;
  const ExercisePickerScreen({
    super.key,
    this.replaceIndex,
    this.returnMode = false,
    this.alreadyAddedIds = const {},
  });

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  String _query = '';
  final Set<String> _activeMuscleGroups = {};
  final Set<String> _activeTags = {};
  final _controller = TextEditingController();
  final Set<String> _selectedIds = {};

  bool get _isReplaceMode => widget.replaceIndex != null;
  bool get _isReturnMode => widget.returnMode;

  static const _muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs',
    'Core', 'Full Body', 'Cardio',
  ];

  static const _movementTags = ['Push', 'Pull'];
  static const _typeTags = ['Compound', 'Isolation', 'Bodyweight', 'Unilateral'];

  List<Exercise> _filtered(List<Exercise> all) {
    var list = all;
    if (_activeMuscleGroups.isNotEmpty) {
      list = list.where((e) => _activeMuscleGroups.contains(e.muscleGroup)).toList();
    }
    if (_activeTags.isNotEmpty) {
      list = list
          .where((e) => _activeTags.every((tag) => e.tags.contains(tag)))
          .toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.muscleGroup.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Map<String, List<Exercise>> _grouped(List<Exercise> exercises) {
    if (_activeMuscleGroups.isNotEmpty || _activeTags.isNotEmpty || _query.isNotEmpty) {
      final sorted = [...exercises]
        ..sort((a, b) => b.timesPerformed.compareTo(a.timesPerformed));
      return {'Results': sorted};
    }
    final performed = exercises.where((e) => e.timesPerformed > 0).toList()
      ..sort((a, b) => b.timesPerformed.compareTo(a.timesPerformed));
    final unperformed = exercises.where((e) => e.timesPerformed == 0).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return {
      if (performed.isNotEmpty) 'My Exercises': performed,
      if (unperformed.isNotEmpty) 'All Exercises': unperformed,
    };
  }

  void _toggleSelect(Exercise ex) {
    if (widget.alreadyAddedIds.contains(ex.id)) return;
    if (_isReplaceMode) {
      final p = context.read<WorkoutProvider>();
      p.replaceExercise(widget.replaceIndex!, ex);
      Navigator.pop(context);
      return;
    }
    setState(() {
      if (_selectedIds.contains(ex.id)) {
        _selectedIds.remove(ex.id);
      } else {
        _selectedIds.add(ex.id);
      }
    });
  }

  void _showCustomOptions(BuildContext context, Exercise ex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(ex.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              title: const Text('Edit Exercise',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                showCreateExerciseSheet(context, existing: ex);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title:
                  const Text('Delete Exercise', style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, ex);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Exercise ex) {
    final provider = context.read<WorkoutProvider>();
    final count = provider.customExerciseSessionCount(ex.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${ex.name}"?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          count > 0
              ? 'This exercise appears in $count session${count == 1 ? '' : 's'}. The history will remain but the exercise will no longer appear in the picker.'
              : 'This will permanently remove the exercise.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              provider.deleteCustomExercise(ex.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  void _addSelected(List<Exercise> allExercises) {
    // preserve tap order by iterating _selectedIds (LinkedHashSet = insertion order)
    final selected = _selectedIds
        .map((id) => allExercises.firstWhere((e) => e.id == id))
        .toList();
    if (selected.isEmpty) return;
    if (_isReturnMode) {
      Navigator.pop(context, selected);
      return;
    }
    context.read<WorkoutProvider>().addExercises(selected);
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<WorkoutProvider>().exercises;
    final filtered = _filtered(exercises.toList());
    final grouped = _grouped(filtered);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Search exercises',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
      ),
      body: Column(
        children: [
          // Unified filter button
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                _FilterButton(
                  activeMuscleGroups: _activeMuscleGroups,
                  activeTags: _activeTags,
                  muscleGroups: _muscleGroups,
                  movementTags: _movementTags,
                  typeTags: _typeTags,
                  onChanged: (muscles, tags) => setState(() {
                    _activeMuscleGroups
                      ..clear()
                      ..addAll(muscles);
                    _activeTags
                      ..clear()
                      ..addAll(tags);
                  }),
                ),
                if (_activeMuscleGroups.isNotEmpty || _activeTags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      _activeMuscleGroups.clear();
                      _activeTags.clear();
                    }),
                    child: const Icon(Icons.close,
                        color: AppColors.textSecondary, size: 18),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: AppColors.divider, height: 1),
          Expanded(
            child: ListView(
              children: [
                // Create custom exercise button
                InkWell(
                  onTap: () => showCreateExerciseSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.blue.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: AppColors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Text('Create Exercise',
                          style: TextStyle(
                              color: AppColors.blue,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                const Divider(color: AppColors.divider, height: 1),
                for (final entry in grouped.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(entry.key,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                  ...entry.value.map((ex) => _ExerciseRow(
                        exercise: ex,
                        isSelected: _selectedIds.contains(ex.id),
                        isReplaceMode: _isReplaceMode,
                        isAlreadyAdded: widget.alreadyAddedIds.contains(ex.id),
                        onTap: () => _toggleSelect(ex),
                        onLongPress: ex.isCustom
                            ? () => _showCustomOptions(context, ex)
                            : null,
                      )),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !_isReplaceMode && _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: () => _addSelected(exercises.toList()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _isReturnMode
                        ? 'Add ${_selectedIds.length} Exercise${_selectedIds.length == 1 ? '' : 's'} to Template'
                        : 'Add ${_selectedIds.length} Exercise${_selectedIds.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

}

class _ExerciseRow extends StatelessWidget {
  final Exercise exercise;
  final bool isSelected;
  final bool isReplaceMode;
  final bool isAlreadyAdded;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ExerciseRow({
    required this.exercise,
    required this.isSelected,
    required this.isReplaceMode,
    required this.onTap,
    this.isAlreadyAdded = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = isAlreadyAdded;
    return InkWell(
      onTap: dimmed ? null : onTap,
      onLongPress: dimmed ? null : onLongPress,
      child: Opacity(
        opacity: dimmed ? 0.4 : 1.0,
        child: Container(
          color: isSelected ? AppColors.blue.withValues(alpha: 0.1) : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: isSelected ? AppColors.blue : AppColors.surface,
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(exercise.muscleGroup[0],
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(exercise.name,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (exercise.isCustom) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Custom',
                              style: TextStyle(
                                  color: AppColors.blue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ]),
                    Row(children: [
                      Text(exercise.muscleGroup,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      if (exercise.tags.isNotEmpty) ...[
                        const Text(' · ',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 13)),
                        Text(exercise.tags.take(2).join(' · '),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ]),
                  ],
                ),
              ),
              if (dimmed)
                const Text('Added',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
              else if (!isReplaceMode)
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.blue : AppColors.textSecondary,
                  size: 22,
                )
              else if (exercise.timesPerformed > 0)
                Text('${exercise.timesPerformed}×',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final Set<String> activeMuscleGroups;
  final Set<String> activeTags;
  final List<String> muscleGroups;
  final List<String> movementTags;
  final List<String> typeTags;
  final void Function(Set<String> muscles, Set<String> tags) onChanged;

  const _FilterButton({
    required this.activeMuscleGroups,
    required this.activeTags,
    required this.muscleGroups,
    required this.movementTags,
    required this.typeTags,
    required this.onChanged,
  });

  int get _total => activeMuscleGroups.length + activeTags.length;

  String get _label {
    if (_total == 0) return 'Filter';
    if (_total == 1) {
      return activeMuscleGroups.isNotEmpty
          ? activeMuscleGroups.first
          : activeTags.first;
    }
    return '$_total filters';
  }

  @override
  Widget build(BuildContext context) {
    final hasTag = _total > 0;
    return GestureDetector(
      onTap: () => _showSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasTag ? AppColors.blue : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune,
                color: hasTag ? Colors.white : AppColors.textSecondary,
                size: 14),
            const SizedBox(width: 6),
            Text(
              _label,
              style: TextStyle(
                color: hasTag ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: hasTag ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down,
                color: hasTag ? Colors.white : AppColors.textSecondary,
                size: 16),
          ],
        ),
      ),
    );
  }

  void _showSheet(BuildContext context) {
    Set<String> localMuscles = Set.from(activeMuscleGroups);
    Set<String> localTags = Set.from(activeTags);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Filter',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    if (localMuscles.isNotEmpty || localTags.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setS(() {
                            localMuscles.clear();
                            localTags.clear();
                          });
                          onChanged({}, {});
                        },
                        child: const Text('Clear all',
                            style: TextStyle(color: AppColors.red, fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionLabel('Muscle Group'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: muscleGroups.map((g) {
                    final sel = localMuscles.contains(g);
                    return _tagChip(g, sel, () {
                      setS(() {
                        if (sel) { localMuscles.remove(g); } else { localMuscles.add(g); }
                      });
                      onChanged(Set.from(localMuscles), Set.from(localTags));
                    });
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _sectionLabel('Movement'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: movementTags.map((tag) {
                    final sel = localTags.contains(tag);
                    return _tagChip(tag, sel, () {
                      setS(() {
                        if (sel) { localTags.remove(tag); } else { localTags.add(tag); }
                      });
                      onChanged(Set.from(localMuscles), Set.from(localTags));
                    });
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _sectionLabel('Type'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: typeTags.map((tag) {
                    final sel = localTags.contains(tag);
                    return _tagChip(tag, sel, () {
                      setS(() {
                        if (sel) { localTags.remove(tag); } else { localTags.add(tag); }
                      });
                      onChanged(Set.from(localMuscles), Set.from(localTags));
                    });
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5));
  }

  Widget _tagChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.blue : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.blue : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textPrimary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
