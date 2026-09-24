import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../state/auth_state.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';

class TaskFeedScreen extends StatefulWidget {
  const TaskFeedScreen({super.key});

  @override
  State<TaskFeedScreen> createState() => _TaskFeedScreenState();
}

class _TaskFeedScreenState extends State<TaskFeedScreen> {
  List<Task> _tasks = [];
  bool _loading = true;
  String? _error;
  String? _categoryFilter; // null = all

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await _resolvePosition();
      final client = context.read<AuthState>().client;
      final tasks = await TaskService(client).nearby(
        lat: position.latitude,
        lng: position.longitude,
        category: _categoryFilter,
      );
      setState(() => _tasks = tasks);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position> _resolvePosition() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied || requested == LocationPermission.deniedForever) {
        throw Exception('Location permission is required to find nearby gigs');
      }
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby gigs'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _categoryFilter == null,
                  onSelected: (_) => setState(() {
                    _categoryFilter = null;
                    _load();
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Chore'),
                  selected: _categoryFilter == 'CHORE',
                  onSelected: (_) => setState(() {
                    _categoryFilter = 'CHORE';
                    _load();
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Social'),
                  selected: _categoryFilter == 'SOCIAL',
                  onSelected: (_) => setState(() {
                    _categoryFilter = 'SOCIAL';
                    _load();
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(children: [_errorState(_error!)])
                : _tasks.isEmpty
                    ? ListView(children: const [Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: Text('No open gigs near you right now.')),
                      )])
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 8, bottom: 80),
                        itemCount: _tasks.length,
                        itemBuilder: (context, i) => TaskCard(
                          task: _tasks[i],
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: _tasks[i].id)),
                            );
                            _load();
                          },
                        ),
                      ),
      ),
    );
  }

  Widget _errorState(String message) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
}
