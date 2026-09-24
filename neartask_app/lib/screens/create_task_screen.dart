import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../services/task_service.dart';
import '../state/auth_state.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _minAgeController = TextEditingController();
  final _maxAgeController = TextEditingController();
  String _category = 'CHORE';
  String? _genderPreference;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      final client = context.read<AuthState>().client;
      await TaskService(client).createTask(
        category: _category,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        latitude: position.latitude,
        longitude: position.longitude,
        genderPreference: _category == 'SOCIAL' ? _genderPreference : null,
        minAge: _category == 'SOCIAL' && _minAgeController.text.isNotEmpty
            ? int.tryParse(_minAgeController.text)
            : null,
        maxAge: _category == 'SOCIAL' && _maxAgeController.text.isNotEmpty
            ? int.tryParse(_maxAgeController.text)
            : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gig posted — funds locked from your wallet.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSocial = _category == 'SOCIAL';
    return Scaffold(
      appBar: AppBar(title: const Text('Post a gig')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'CHORE', label: Text('Chore / Errand')),
              ButtonSegment(value: 'SOCIAL', label: Text('Social')),
            ],
            selected: {_category},
            onSelectionChanged: (s) => setState(() => _category = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Price (₹)', border: OutlineInputBorder()),
          ),
          if (isSocial) ...[
            const SizedBox(height: 20),
            const Text('Safety preferences (optional, Social gigs only)',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _genderPreference,
              decoration: const InputDecoration(labelText: 'Gender preference', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: null, child: Text('No preference')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                DropdownMenuItem(value: 'MALE', child: Text('Male')),
              ],
              onChanged: (v) => setState(() => _genderPreference = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minAgeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min age', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxAgeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max age', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'This amount will be locked from your wallet as soon as you post. It stays refundable until you select an applicant.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _loading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post gig'),
          ),
        ],
      ),
    );
  }
}
