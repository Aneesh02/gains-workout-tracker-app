import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import 'create_exercise_sheet.dart';
import 'exercise_detail_screen.dart';

enum _SortMode { mostDone, nameAZ, muscleGroup }

class ExercisesTabScreen extends StatefulWidget {
  const ExercisesTabScreen({super.key});

  @override
  State<ExercisesTabScreen> createState() => _ExercisesTabScreenState();
}

class _ExercisesTabScreenState extends State<ExercisesTabScreen> {
  String _query = '';
  bool _searchActive = false;
  final Set<String> _activeMuscleGroups = {};
  final Set<String> _activeTags = {};
  _SortMode _sortMode = _SortMode.mostDone;
  final _searchController = TextEditingController();

  static const _muscleGroups = [
    'Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core', 'Full Body', 'Cardio',
  ];
  static const _movementTags = ['Push', 'Pull'];
  static const _typeTags = ['Compound', 'Isolation', 'Bodyweight', 'Unilateral'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Exercise> _filtered(List<Exercise> all) {
    var list = all;
    if (_activeMuscleGroups.isNotEmpty) {
      list = list.where((e) => _activeMuscleGroups.contains(e.muscleGroup)).toList();
    }
    if (_activeTags.isNotEmpty) {
      list = list.where((e) => _activeTags.every((t) => e.tags.contains(t))).toList();
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
    final hasFilter = _activeMuscleGroups.isNotEmpty ||
        _activeTags.isNotEmpty ||
        _query.isNotEmpty;

    if (hasFilter) {
      final sorted = [...exercises]
        ..sort((a, b) => b.timesPerformed.compareTo(a.timesPerformed));
      return {'Results (${sorted.length})': sorted};
    }

    switch (_sortMode) {
      case _SortMode.nameAZ:
        final sorted = [...exercises]..sort((a, b) => a.name.compareTo(b.name));
        return {'All Exercises': sorted};

      case _SortMode.muscleGroup:
        final groups = <String, List<Exercise>>{};
        for (final ex in exercises) {
          groups.putIfAbsent(ex.muscleGroup, () => []).add(ex);
        }
        for (final list in groups.values) {
          list.sort((a, b) => a.name.compareTo(b.name));
        }
        final sortedKeys = groups.keys.toList()..sort();
        return {for (final k in sortedKeys) k: groups[k]!};

      case _SortMode.mostDone:
        final f50 = exercises.where((e) => e.timesPerformed >= 50).toList()
          ..sort((a, b) => b.timesPerformed.compareTo(a.timesPerformed));
        final f26 = exercises
            .where((e) => e.timesPerformed >= 26 && e.timesPerformed < 50)
            .toList()
          ..sort((a, b) => b.timesPerformed.compareTo(a.timesPerformed));
        final f11 = exercises
            .where((e) => e.timesPerformed >= 11 && e.timesPerformed < 26)
            .toList()
          ..sort((a, b) => b.timesPerformed.compareTo(a.timesPerformed));
        final rest = exercises.where((e) => e.timesPerformed <= 10).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return {
          if (f50.isNotEmpty) '50+ times': f50,
          if (f26.isNotEmpty) '26–50 times': f26,
          if (f11.isNotEmpty) '11–25 times': f11,
          'All Exercises': rest,
        };
    }
  }

  void _toggleSearch() {
    setState(() {
      _searchActive = !_searchActive;
      if (!_searchActive) {
        _query = '';
        _searchController.clear();
      }
    });
  }

  void _showFilterSheet() {
    // Local copies so the sheet can setState independently
    Set<String> localMuscles = Set.from(_activeMuscleGroups);
    Set<String> localTags = Set.from(_activeTags);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 8,
            ),
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
                          setState(() {
                            _activeMuscleGroups.clear();
                            _activeTags.clear();
                          });
                        },
                        child: const Text('Clear all',
                            style: TextStyle(
                                color: AppColors.red, fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _sectionLabel('Muscle Group'),
                const SizedBox(height: 8),
                _chipWrap(_muscleGroups, localMuscles, (item, sel) {
                  setS(() {
                    if (sel) {
                      localMuscles.remove(item);
                    } else {
                      localMuscles.add(item);
                    }
                  });
                  setState(() {
                    _activeMuscleGroups
                      ..clear()
                      ..addAll(localMuscles);
                  });
                }),
                const SizedBox(height: 16),
                _sectionLabel('Movement'),
                const SizedBox(height: 8),
                _chipWrap(_movementTags, localTags, (item, sel) {
                  setS(() {
                    if (sel) {
                      localTags.remove(item);
                    } else {
                      localTags.add(item);
                    }
                  });
                  setState(() {
                    _activeTags
                      ..clear()
                      ..addAll(localTags);
                  });
                }),
                const SizedBox(height: 16),
                _sectionLabel('Type'),
                const SizedBox(height: 8),
                _chipWrap(_typeTags, localTags, (item, sel) {
                  setS(() {
                    if (sel) {
                      localTags.remove(item);
                    } else {
                      localTags.add(item);
                    }
                  });
                  setState(() {
                    _activeTags
                      ..clear()
                      ..addAll(localTags);
                  });
                }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort by',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            _sortTile('Most Done', _SortMode.mostDone),
            _sortTile('Name A–Z', _SortMode.nameAZ),
            _sortTile('Muscle Group', _SortMode.muscleGroup),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sortTile(String label, _SortMode mode) {
    final selected = _sortMode == mode;
    return ListTile(
      title: Text(label,
          style: TextStyle(
              color: selected ? AppColors.blue : AppColors.textPrimary,
              fontWeight:
                  selected ? FontWeight.bold : FontWeight.normal)),
      trailing:
          selected ? const Icon(Icons.check, color: AppColors.blue) : null,
      onTap: () {
        setState(() => _sortMode = mode);
        Navigator.pop(context);
      },
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));

  Widget _chipWrap(List<String> items, Set<String> active,
      void Function(String item, bool selected) onToggle) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final sel = active.contains(item);
        return GestureDetector(
          onTap: () => onToggle(item, sel),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? AppColors.blue : AppColors.background,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? AppColors.blue : AppColors.divider),
            ),
            child: Text(item,
                style: TextStyle(
                    color: sel ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight:
                        sel ? FontWeight.bold : FontWeight.normal)),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final exercises = context.watch<WorkoutProvider>().exercises;
    final filtered = _filtered(exercises.toList());
    final grouped = _grouped(filtered);
    final hasFilters = _activeMuscleGroups.isNotEmpty || _activeTags.isNotEmpty;
    final nonDefaultSort = _sortMode != _SortMode.mostDone;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.background,
          expandedHeight: 80,
          actions: [
            IconButton(
              icon: const Icon(Icons.add, color: AppColors.blue),
              onPressed: () => showCreateExerciseSheet(context),
              tooltip: 'Create Exercise',
            ),
            IconButton(
              icon: Icon(
                _searchActive ? Icons.search_off : Icons.search,
                color: _searchActive
                    ? AppColors.blue
                    : AppColors.textSecondary,
              ),
              onPressed: _toggleSearch,
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: Icon(Icons.filter_list,
                      color: hasFilters
                          ? AppColors.blue
                          : AppColors.textSecondary),
                  onPressed: _showFilterSheet,
                ),
                if (hasFilters)
                  Positioned(
                    right: 8,
                    top: 10,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: Icon(Icons.sort,
                  color: nonDefaultSort
                      ? AppColors.blue
                      : AppColors.textSecondary),
              onPressed: _showSortSheet,
            ),
          ],
          bottom: _searchActive
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(52),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Search exercises',
                          hintStyle: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.search,
                              color: AppColors.textSecondary, size: 18),
                          contentPadding:
                              EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ),
                )
              : null,
          flexibleSpace: const FlexibleSpaceBar(
            titlePadding: EdgeInsets.only(left: 16, bottom: 12),
            title: Text('Exercises',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final entry = grouped.entries.toList()[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(entry.key,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  ...entry.value.map((ex) => _ExerciseRow(exercise: ex)),
                ],
              );
            },
            childCount: grouped.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final Exercise exercise;

  const _ExerciseRow({required this.exercise});

  void _showCustomOptions(BuildContext context) {
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
                child: Text(exercise.name,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
              leading:
                  const Icon(Icons.info_outline, color: AppColors.textSecondary),
              title: const Text('View Details',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ExerciseDetailScreen(exercise: exercise)),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
              title: const Text('Edit Exercise',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                showCreateExerciseSheet(context, existing: exercise);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.red),
              title: const Text('Delete Exercise',
                  style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final provider = context.read<WorkoutProvider>();
    final count = provider.customExerciseSessionCount(exercise.id);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete "${exercise.name}"?',
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(
          count > 0
              ? 'This exercise appears in $count session${count == 1 ? '' : 's'}. The history will remain but the exercise will be removed.'
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
              provider.deleteCustomExercise(exercise.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(exercise: exercise)),
      ),
      onLongPress: exercise.isCustom ? () => _showCustomOptions(context) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surface,
            child: Text(exercise.muscleGroup[0],
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
                            color: AppColors.textPrimary, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (exercise.isCustom) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          if (exercise.timesPerformed > 0)
            Text('${exercise.timesPerformed}×',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
        ]),
      ),
    );
  }
}
