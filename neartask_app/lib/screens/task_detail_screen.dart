import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../services/task_service.dart';
import '../state/auth_state.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Task? _task;
  bool _loading = true;
  String? _error;
  bool _acting = false;
  final _noteController = TextEditingController();
  final _ratingCommentController = TextEditingController();
  int _selectedScore = 5;

  late TaskService _taskService;

  @override
  void initState() {
    super.initState();
    _taskService = TaskService(context.read<AuthState>().client);
    _load();
  }

  Future<void> _showDisputeDialog() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report a problem'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'This flags the gig for NearTask support to review. Funds stay locked until they resolve it — nothing is refunded or released automatically.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'What went wrong?', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    if (reason == null || reason.length < 10) return;
    await _runAction(() => _taskService.raiseDispute(widget.taskId, reason));
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await _taskService.getTask(widget.taskId);
      setState(() => _task = t);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(Future<void> Function() action, {String? confirmMessage}) async {
    if (confirmMessage != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          content: Text(confirmMessage),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => _acting = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthState>().currentUser;
    final isCreator = _task != null && me != null && _task!.creatorId == me.id;
    final myApplication =
        _task != null && me != null ? _task!.applications.where((a) => a.applicantId == me.id).firstOrNull : null;

    return Scaffold(
      appBar: AppBar(title: Text(_task?.title ?? 'Gig')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Chip(label: Text(_task!.category)),
                        const Spacer(),
                        Text('₹${_task!.price.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(_task!.description, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 8),
                    Text('Status: ${_task!.status}', style: TextStyle(color: Colors.grey.shade600)),
                    const Divider(height: 32),

                    if (isCreator) ..._creatorControls() else ..._applicantControls(myApplication),

                    if (_task!.status == 'COMPLETED' && me != null) ..._ratingSection(_task!, me.id, isCreator),
                  ],
                ),
    );
  }

  List<Widget> _creatorControls() {
    final task = _task!;
    if (task.status == 'OPEN') {
      return [
        const Text('Applicants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (task.applications.isEmpty) const Text('No applicants yet.'),
        ...task.applications.map((a) => Card(
              child: ListTile(
                title: Text(a.applicantName ?? 'Applicant'),
                subtitle: a.note != null && a.note!.isNotEmpty ? Text(a.note!) : null,
                trailing: ElevatedButton(
                  onPressed: _acting
                      ? null
                      : () => _runAction(() => _taskService.selectApplicant(task.id, a.id),
                          confirmMessage: 'Select ${a.applicantName ?? 'this applicant'}? Everyone else will be declined.'),
                  child: const Text('Select'),
                ),
              ),
            )),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _acting
              ? null
              : () => _runAction(() => _taskService.cancel(task.id),
                  confirmMessage: 'Cancel this gig? You will get a partial refund since no one has been selected yet.'),
          child: const Text('Cancel this gig'),
        ),
      ];
    }
    if (task.status == 'SELECTED' || task.status == 'IN_PROGRESS') {
      return [
        const Text('An applicant has been selected. No refund applies if you cancel from here.',
            style: TextStyle(color: Colors.orange)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _acting
              ? null
              : () => _runAction(() => _taskService.complete(task.id),
                  confirmMessage: 'Mark this gig complete? Funds will be released to the doer.'),
          child: const Text('Mark complete & release payment'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _acting
              ? null
              : () => _runAction(() => _taskService.reportNoShow(task.id),
                  confirmMessage: 'Report the selected doer as a no-show? You will get a full refund.'),
          child: const Text('Report no-show'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: _acting ? null : _showDisputeDialog, child: const Text('Report a different problem')),
      ];
    }
    if (task.status == 'DISPUTED') {
      return [
        const Icon(Icons.gavel_outlined, size: 32, color: Colors.orange),
        const SizedBox(height: 8),
        const Text(
          'This gig is under review by NearTask support. Funds stay locked until it\'s resolved.',
          textAlign: TextAlign.center,
        ),
      ];
    }
    return [Text('This gig is ${task.status.toLowerCase()}.')];
  }

  List<Widget> _applicantControls(dynamic myApplication) {
    final task = _task!;
    if (task.status == 'DISPUTED') {
      return [
        const Icon(Icons.gavel_outlined, size: 32, color: Colors.orange),
        const SizedBox(height: 8),
        const Text(
          'This gig is under review by NearTask support. Funds stay locked until it\'s resolved.',
          textAlign: TextAlign.center,
        ),
      ];
    }
    if (task.status == 'SELECTED' || task.status == 'IN_PROGRESS') {
      if (myApplication != null && myApplication.status == 'SELECTED') {
        return [
          const Text('You\'re confirmed for this gig. The creator will mark it complete once it\'s done.'),
          const SizedBox(height: 8),
          TextButton(onPressed: _acting ? null : _showDisputeDialog, child: const Text('Report a problem')),
        ];
      }
    }
    if (task.status != 'OPEN') {
      return [Text('This gig is ${task.status.toLowerCase()} and no longer accepting applicants.')];
    }
    if (myApplication != null) {
      return [Text('You applied — status: ${myApplication.status}. The creator will pick one applicant.')];
    }
    return [
      const Text('Interested? Send a short note with your application.'),
      const SizedBox(height: 8),
      TextField(
        controller: _noteController,
        decoration: const InputDecoration(hintText: 'e.g. I can start in 20 minutes', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: _acting
            ? null
            : () => _runAction(() => _taskService.apply(task.id, note: _noteController.text.trim())),
        child: const Text('Apply'),
      ),
    ];
  }

  List<Widget> _ratingSection(Task task, String myId, bool isCreator) {
    final counterpartId = isCreator
        ? task.applications.where((a) => a.status == 'SELECTED').map((a) => a.applicantId).firstOrNull
        : task.creatorId;
    if (counterpartId == null) return [];

    final alreadyRated = task.ratings.any((r) => r.fromUserId == myId);
    if (alreadyRated) {
      return [
        const Divider(height: 32),
        const Text('Thanks for rating this gig.', style: TextStyle(color: Colors.grey)),
      ];
    }

    return [
      const Divider(height: 32),
      Text(isCreator ? 'Rate the doer' : 'Rate the creator', style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Row(
        children: List.generate(5, (i) {
          final starValue = i + 1;
          return IconButton(
            onPressed: () => setState(() => _selectedScore = starValue),
            icon: Icon(
              starValue <= _selectedScore ? Icons.star : Icons.star_border,
              color: Colors.amber,
            ),
          );
        }),
      ),
      TextField(
        controller: _ratingCommentController,
        decoration: const InputDecoration(hintText: 'Optional comment', border: OutlineInputBorder()),
      ),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: _acting
            ? null
            : () => _runAction(() => _taskService.rateTask(
                  task.id,
                  toUserId: counterpartId,
                  score: _selectedScore,
                  comment: _ratingCommentController.text.trim(),
                )),
        child: const Text('Submit rating'),
      ),
    ];
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
