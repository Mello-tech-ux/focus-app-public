import 'dart:async';

import 'package:flutter/material.dart';

import 'models/availability_window.dart';
import 'models/study_module.dart';
import 'models/study_preferences.dart';
import 'screens/availability_screen.dart';
import 'screens/modules_screen.dart';
import 'screens/study_preferences_screen.dart';

void main() => runApp(const FocusApp());

class FocusApp extends StatelessWidget {
  const FocusApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF315E51);
    return MaterialApp(
      title: 'FOCUS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF8FAF7),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _titleController;
  late final AnimationController _meaningController;
  Timer? _meaningRevealTimer;

  @override
  void initState() {
    super.initState();
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _meaningController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _meaningRevealTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _meaningController.forward();
    });
  }

  @override
  void dispose() {
    _meaningRevealTimer?.cancel();
    _titleController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  void _enterFocus() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const FocusHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Icon(Icons.menu_book_rounded, color: colors.primary),
              ),
              const Spacer(flex: 3),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _titleController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .18),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _titleController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: Text(
                    'FOCUS',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _meaningController,
                  curve: Curves.easeOut,
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, .12),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _meaningController,
                    curve: Curves.easeOutCubic,
                  )),
                  child: Text(
                    'Focused Organization for Consistent Undergraduate Study.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1.35,
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _meaningController,
                  curve: Curves.easeOut,
                ),
                child: Text(
                  'A calmer way to plan your study time and stay on track.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ),
              const Spacer(flex: 4),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _enterFocus,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Enter FOCUS'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FocusHomeScreen extends StatefulWidget {
  const FocusHomeScreen({super.key});

  @override
  State<FocusHomeScreen> createState() => _FocusHomeScreenState();
}

class _FocusHomeScreenState extends State<FocusHomeScreen> {
  List<StudyModule> _modules = [];
  final List<AvailabilityWindow> _availability = [];
  StudyPreferences _preferences = const StudyPreferences();

  Future<void> _openModules() async {
    final modules = await Navigator.of(context).push<List<StudyModule>>(
      MaterialPageRoute<List<StudyModule>>(
        builder: (_) => ModulesScreen(initialModules: _modules),
      ),
    );
    if (modules != null && mounted) setState(() => _modules = modules);
  }

  Future<void> _openAvailability() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AvailabilityScreen(initialWindows: _availability),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openPreferences() async {
    final preferences = await Navigator.of(context).push<StudyPreferences>(
      MaterialPageRoute<StudyPreferences>(
        builder: (_) => StudyPreferencesScreen(initialPreferences: _preferences),
      ),
    );
    if (preferences != null && mounted) setState(() => _preferences = preferences);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FOCUS'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: CircleAvatar(child: Icon(Icons.person_outline_rounded)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'Build a steady study rhythm.',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 24),
          const _HomeSection(
            title: "Today's Study",
            description: 'Your study plan for today will appear here.',
            icon: Icons.today_outlined,
          ),
          const SizedBox(height: 16),
          const _HomeSection(
            title: 'Upcoming Sessions',
            description: 'Keep an eye on what is coming next.',
            icon: Icons.event_note_outlined,
          ),
          const SizedBox(height: 16),
          _HomeSection(
            title: 'My Modules',
            description: _modules.isEmpty
                ? 'Add the subjects you are working through.'
                : '${_modules.length} module${_modules.length == 1 ? '' : 's'} in your study plan.',
            icon: Icons.auto_stories_outlined,
            onTap: _openModules,
          ),
          const SizedBox(height: 16),
          _HomeSection(
            title: 'My Availability',
            description: _availability.isEmpty
                ? 'Set the times you are available to study.'
                : '${_availability.length} availability window${_availability.length == 1 ? '' : 's'} configured.',
            icon: Icons.schedule_outlined,
            onTap: _openAvailability,
          ),
          const SizedBox(height: 16),
          _HomeSection(
            title: 'Study Preferences',
            description: '${_preferences.preferredStudyPeriod.label} • ${_preferences.preferredSessionMinutes} min sessions',
            icon: Icons.tune_outlined,
            onTap: _openPreferences,
          ),
        ],
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: colors.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
