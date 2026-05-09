import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/workout_provider.dart';
import 'theme/app_theme.dart';
import 'screens/workout_tab_screen.dart';
import 'screens/history_screen.dart';
import 'screens/exercises_tab_screen.dart';
import 'screens/active_workout_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/metrics_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox('strongclone');
  final syncBox = await Hive.openBox('syncstate');
  final provider = WorkoutProvider(box, syncBox);
  runApp(
    ChangeNotifierProvider(
      create: (_) => provider,
      child: const MyApp(),
    ),
  );
  // Seed history after the app is running — background isolate, non-blocking.
  provider.seedFromAsset();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: AppTheme.theme,
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 2;

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const ProfileScreen(),
      const HistoryScreen(),
      const WorkoutTabScreen(),
      const ExercisesTabScreen(),
      const MetricsScreen(),
    ];

    final hasWorkout = context.watch<WorkoutProvider>().hasActiveWorkout;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: tabs[_tab],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasWorkout) const _WorkoutBanner(),
          BottomNavigationBar(
            currentIndex: _tab,
            onTap: (i) => setState(() => _tab = i),
            items: const [
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline), label: 'Profile'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.add), label: 'Workout'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.fitness_center), label: 'Exercises'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.insights), label: 'Metrics'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WorkoutBanner extends StatefulWidget {
  const _WorkoutBanner();

  @override
  State<_WorkoutBanner> createState() => _WorkoutBannerState();
}

class _WorkoutBannerState extends State<_WorkoutBanner> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>().activeWorkout;
    if (workout == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveWorkoutScreen()),
      ),
      child: Container(
        color: AppColors.blue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.fitness_center, color: Colors.white, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                workout.name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              workout.elapsedLabel,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.expand_less, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
