import 'package:flutter/material.dart';

import '../services/contact_service.dart';
import '../widgets/app_header.dart';
import '../widgets/app_logo.dart';

class ContactAdminScreen extends StatefulWidget {
  const ContactAdminScreen({super.key});

  @override
  State<ContactAdminScreen> createState() => _ContactAdminScreenState();
}

class _ContactAdminScreenState extends State<ContactAdminScreen> {
  final _emailController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _concerns = const [
    'Forgot Password',
    'Email/Login Concern',
    'Account Concern',
    'Other',
  ];
  String _concernType = 'Forgot Password';
  bool _isSubmitting = false;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  int get _wordCount {
    final words = _descriptionController.text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    return words.length;
  }

  bool get _isValid {
    return _emailPattern.hasMatch(_emailController.text.trim()) &&
        _wordCount > 0 &&
        _wordCount <= 20;
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _isSubmitting = true);
    try {
      await ContactService().submitRequest(
        email: _emailController.text.trim(),
        concernType: _concernType,
        description: _descriptionController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request submitted. An admin will follow up by email.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to submit right now. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'CONTACT ADMIN',
        showBack: true,
        showLogoTrailing: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: AppLogo(size: 84)),
              const SizedBox(height: 16),
              const Text(
                'Need help logging in?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2D3D),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Concern Type',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _concernType,
                items: _concerns
                    .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _concernType = value);
                },
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              const Text('Email', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Email associated with your account',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                onChanged: (value) {
                  final words = value
                      .trim()
                      .split(RegExp(r'\s+'))
                      .where((word) => word.isNotEmpty)
                      .toList();
                  if (words.length > 20) {
                    _descriptionController.text = words.take(20).join(' ');
                    _descriptionController.selection = TextSelection.collapsed(
                      offset: _descriptionController.text.length,
                    );
                  }
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'Describe your concern',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$_wordCount / 20 words',
                  style: TextStyle(
                    fontSize: 12,
                    color: _wordCount > 20 ? Colors.red : const Color(0xFF607080),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _isValid && !_isSubmitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF118339),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Submit Request'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
