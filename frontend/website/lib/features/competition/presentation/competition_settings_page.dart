import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/auth/auth_card.dart';
import '../../../widgets/auth/auth_text_field.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../../home/presentation/home_page.dart';
import '../data/competition_repository.dart';
import '../state/competition_details_controller.dart';
import 'competition_dashboard_page.dart';

class CompetitionSettingsPage extends ConsumerStatefulWidget {
  const CompetitionSettingsPage({super.key, required this.competitionId});

  static const routeName = 'competition-settings';
  static const routePath = '/competitions/:id/settings';

  final String competitionId;

  static String routeForId(String id) => '/competitions/$id/settings';

  @override
  ConsumerState<CompetitionSettingsPage> createState() =>
      _CompetitionSettingsPageState();
}

class _CompetitionSettingsPageState
    extends ConsumerState<CompetitionSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _invitationController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime? _launchDate;
  String? _loadedId;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _invitationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _applyCompetitionData(competition) {
    if (_loadedId == competition.id) {
      return;
    }
    _loadedId = competition.id;
    _nameController.text = competition.name;
    _descriptionController.text = competition.description ?? '';
    _invitationController.text = competition.invitationLink ?? '';
    _launchDate = competition.launchDate;
    _dateController.text = _launchDate == null
        ? ''
        : '${_launchDate!.year}-${_two(_launchDate!.month)}-${_two(_launchDate!.day)}';
  }

  void _showMessage(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _launchDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (selected != null) {
      setState(() {
        _launchDate = selected;
        _dateController.text =
            '${selected.year}-${_two(selected.month)}-${_two(selected.day)}';
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(competitionRepositoryProvider).updateCompetition(
            competitionId: widget.competitionId,
            name: _nameController.text,
            description: _descriptionController.text,
            invitationLink: _invitationController.text,
            launchDate: _launchDate,
          );
      if (!mounted) return;
      ref.invalidate(competitionDetailsProvider(widget.competitionId));
      _showMessage('Competition updated.');
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete competition'),
          content: const Text(
            'This will permanently remove the competition and its data. '
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(competitionRepositoryProvider)
          .deleteCompetition(widget.competitionId);
      if (!mounted) return;
      _showMessage('Competition deleted.');
      context.go(HomePage.routePath);
    } catch (error) {
      if (!mounted) return;
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final competitionState =
        ref.watch(competitionDetailsProvider(widget.competitionId));

    return AxonScaffold(
      centerContent: true,
      child: competitionState.when(
        data: (competition) {
          _applyCompetitionData(competition);
          return AuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(
                  title: 'Competition settings',
                  subtitle: 'Edit the competition details and access settings.',
                ),
                const SizedBox(height: AppSpacing.lg),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    children: [
                      AuthTextField(
                        controller: _nameController,
                        label: 'Competition name',
                        hint: 'Axon Label Sprint',
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        prefixIcon: Icons.emoji_events_outlined,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'Competition name is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          hintText: 'Explain the goal for participants.',
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: const InputDecoration(
                          labelText: 'Launch date',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AuthTextField(
                        controller: _invitationController,
                        label: 'Invitation link',
                        hint: 'https://axon.ai/invite/1234',
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        prefixIcon: Icons.link,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save changes'),
                ),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _isDeleting ? null : _delete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete competition'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go(
                    CompetitionDashboardPage.routeForId(widget.competitionId),
                  ),
                  child: const Text('Back to dashboard'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => AuthCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(
                title: 'Competition settings',
                subtitle: 'Unable to load competition details.',
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(error.toString()),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () =>
                    ref.refresh(competitionDetailsProvider(widget.competitionId)),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
