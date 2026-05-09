import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/competition_service.dart';
import 'home_screen.dart';

class JoinCompetitionScreen extends ConsumerStatefulWidget {
  const JoinCompetitionScreen({super.key});

  @override
  ConsumerState<JoinCompetitionScreen> createState() =>
      _JoinCompetitionScreenState();
}

class _JoinCompetitionScreenState extends ConsumerState<JoinCompetitionScreen> {
  final _linkController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _joining = false;

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _joining = true);
    try {
      final service = ref.read(competitionServiceProvider);
      await service.joinWithInvitationLink(_linkController.text);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Competition')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.link, size: 48, color: Color(0xFF5F75EE)),
              const SizedBox(height: 16),
              Text(
                'Join a Competition',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paste the invitation link you received from the organizer.',
                style: TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _linkController,
                decoration: const InputDecoration(
                  labelText: 'Invitation link',
                  hintText: 'Paste link here...',
                  prefixIcon: Icon(Icons.vpn_key),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an invitation link';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _joining ? null : _submit,
                  child: _joining
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join Competition'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}