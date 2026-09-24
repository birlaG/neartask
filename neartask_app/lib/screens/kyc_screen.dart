import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/kyc_service.dart';
import '../state/auth_state.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _picker = ImagePicker();
  File? _idDocument;
  File? _selfie;
  bool _submitting = false;
  bool _loadingStatus = true;
  KycSubmission? _existing;
  String? _error;

  late KycService _kycService;

  @override
  void initState() {
    super.initState();
    _kycService = KycService(context.read<AuthState>().token);
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    try {
      final latest = await _kycService.latest();
      setState(() => _existing = latest);
    } catch (_) {
      // no existing submission — fine, treat as fresh
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  Future<void> _pickImage(bool isIdDocument) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    setState(() {
      if (isIdDocument) {
        _idDocument = File(picked.path);
      } else {
        _selfie = File(picked.path);
      }
    });
  }

  Future<void> _submit() async {
    if (_idDocument == null || _selfie == null) {
      setState(() => _error = 'Please add both photos before submitting.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final submission = await _kycService.submit(idDocument: _idDocument!, selfie: _selfie!);
      setState(() => _existing = submission);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Submitted — this is usually reviewed within a day.')));
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Identity verification')),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_existing != null) ..._statusBanner(_existing!),
                if (_existing == null || _existing!.status == 'REJECTED') ..._uploadForm(),
              ],
            ),
    );
  }

  List<Widget> _statusBanner(KycSubmission submission) {
    final color = switch (submission.status) {
      'VERIFIED' => Colors.green,
      'REJECTED' => Colors.red,
      _ => Colors.orange,
    };
    final label = switch (submission.status) {
      'VERIFIED' => 'Verified — you can now post and apply to Social gigs.',
      'REJECTED' => 'Your last submission was rejected${submission.adminNote != null ? ': ${submission.adminNote}' : '.'} Please try again below.',
      _ => 'Pending review. This is usually handled within 24 hours.',
    };
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(
              submission.status == 'VERIFIED' ? Icons.check_circle : Icons.info_outline,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: color))),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  List<Widget> _uploadForm() {
    return [
      const Text(
        'Upload a government ID and a selfie. This unlocks Social gigs and generally makes people more comfortable applying to or accepting your gigs.',
        style: TextStyle(color: Colors.grey),
      ),
      const SizedBox(height: 20),
      _imagePickerTile('ID document', _idDocument, () => _pickImage(true)),
      const SizedBox(height: 16),
      _imagePickerTile('Selfie', _selfie, () => _pickImage(false)),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: const TextStyle(color: Colors.red)),
      ],
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
        child: _submitting
            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Submit for review'),
      ),
    ];
  }

  Widget _imagePickerTile(String label, File? file, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(file, width: double.infinity, fit: BoxFit.cover),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_a_photo_outlined, color: Colors.grey),
                    const SizedBox(height: 6),
                    Text(label, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
      ),
    );
  }
}
