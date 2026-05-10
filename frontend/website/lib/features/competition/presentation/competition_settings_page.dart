import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
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

  // Basic
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _dateCtl = TextEditingController();
  final _inviteCtl = TextEditingController();
  DateTime? _launchDate;

  // Config
  final _overviewCtl = TextEditingController();
  final _termsCtl = TextEditingController();
  final _dataMdCtl = TextEditingController();
  final _dataExCtl = TextEditingController();
  String? _selectedEvaluation;
  String _selectedProtocol = 'standard';
  final _scoringExCtl = TextEditingController();
  final _maxValCtl = TextEditingController();
  final _dupThreshCtl = TextEditingController();

  // Model spec
  final _modelDirCtl = TextEditingController();
  final _dataDirCtl = TextEditingController();
  final _infFuncCtl = TextEditingController();
  final _maxSizeMbCtl = TextEditingController();
  final _pyMinCtl = TextEditingController();
  final Map<String, bool> _formats = {
    'pytorch': true, 'tensorflow': true, 'sklearn': true,
    'keras': true, 'onnx': true,
  };

  // Labels
  final List<String> _labels = [];
  final Set<String> _selectedFormats = {};
  final _labelCtl = TextEditingController();

  String? _loadedId;
  bool _isSaving = false;
  bool _isDeleting = false;
  final Set<int> _expanded = {0};

  @override
  void dispose() {
    for (final c in [
      _nameCtl, _descCtl, _dateCtl, _inviteCtl, _overviewCtl, _termsCtl,
      _dataMdCtl, _dataExCtl, _scoringExCtl,
      _maxValCtl, _dupThreshCtl, _modelDirCtl, _dataDirCtl, _infFuncCtl,
      _maxSizeMbCtl, _pyMinCtl, _labelCtl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyData(dynamic competition) {
    if (_loadedId == competition.id) return;
    _loadedId = competition.id;
    _nameCtl.text = competition.name;
    _descCtl.text = competition.description ?? '';
    _inviteCtl.text = competition.invitationLink ?? '';
    _launchDate = competition.launchDate;
    _dateCtl.text = _launchDate == null
        ? ''
        : '${_launchDate!.year}-${_two(_launchDate!.month)}-${_two(_launchDate!.day)}';

    final cfg = competition.config;
    if (cfg != null) {
      _overviewCtl.text = cfg.overview ?? '';
      _termsCtl.text = cfg.termsConditions ?? '';
      _dataMdCtl.text = cfg.dataMarkdown ?? '';
      if (cfg.dataFormat != null) _selectedFormats.addAll(cfg.dataFormat!);
      _dataExCtl.text = cfg.dataExample ?? '';
      _selectedEvaluation = cfg.evaluation;
      _scoringExCtl.text = cfg.scoringExample ?? '';
      _maxValCtl.text = cfg.maxValidations?.toString() ?? '';
      _dupThreshCtl.text = cfg.duplicateThreshold?.toString() ?? '';

      if (cfg.labels != null) {
        _labels.clear();
        _labels.addAll(cfg.labels!.keys);
      }

      final ms = cfg.modelSpec;
      if (ms != null) {
        _modelDirCtl.text = ms['model_dir'] ?? 'model';
        _dataDirCtl.text = ms['data_dir'] ?? 'data';
        _infFuncCtl.text = ms['inference_function'] ?? 'predict';
        _maxSizeMbCtl.text = (ms['max_size_mb'] ?? 500).toString();
        _pyMinCtl.text = ms['python_version_min'] ?? '';
        _selectedProtocol = ms['evaluation_protocol'] ?? 'standard';
        final allowed = ms['allowed_model_formats'] as List<dynamic>?;
        if (allowed != null) {
          for (final k in _formats.keys) {
            _formats[k] = allowed.contains(k);
          }
        }
      } else {
        _modelDirCtl.text = 'model';
        _dataDirCtl.text = 'data';
        _infFuncCtl.text = 'predict';
        _maxSizeMbCtl.text = '500';
      }
    }
  }

  void _showMsg(String msg, {bool isError = false}) {
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _launchDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (d != null) {
      setState(() {
        _launchDate = d;
        _dateCtl.text = '${d.year}-${_two(d.month)}-${_two(d.day)}';
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(competitionRepositoryProvider);

      await repo.updateCompetition(
        competitionId: widget.competitionId,
        name: _nameCtl.text,
        description: _descCtl.text,
        invitationLink: _inviteCtl.text,
        launchDate: _launchDate,
      );

      final configData = <String, dynamic>{
        'overview': _overviewCtl.text.trim(),
        'terms_conditions': _termsCtl.text.trim(),
        'data_md': _dataMdCtl.text.trim(),
        'data_format': _selectedFormats.isEmpty ? null : _selectedFormats.toList(),
        'data_ex': _dataExCtl.text.trim(),
        'evaluation': _selectedEvaluation,
        'scoring_ex': _scoringExCtl.text.trim(),
        'labels': _labels.isEmpty ? null : {for (var l in _labels) l: {}},
        'model_spec': {
          'required_files': ['Dockerfile', 'inference.py', 'requirements.txt'],
          'model_dir': _modelDirCtl.text.trim(),
          'data_dir': _dataDirCtl.text.trim(),
          'inference_function': _infFuncCtl.text.trim(),
          'allowed_model_formats': _formats.entries
              .where((e) => e.value).map((e) => e.key).toList(),
          'max_size_mb': double.tryParse(_maxSizeMbCtl.text.trim()) ?? 500.0,
          if (_pyMinCtl.text.trim().isNotEmpty)
            'python_version_min': _pyMinCtl.text.trim(),
          'evaluation_protocol': _selectedProtocol,
        },
      };
      final maxVal = int.tryParse(_maxValCtl.text.trim());
      final dupTh = double.tryParse(_dupThreshCtl.text.trim());
      if (maxVal != null) configData['max_validations'] = maxVal;
      if (dupTh != null) configData['duplicate_threshhold'] = dupTh;

      await repo.updateConfig(
        competitionId: widget.competitionId,
        configData: configData,
      );


      if (!mounted) return;
      ref.invalidate(competitionDetailsProvider(widget.competitionId));
      _showMsg('Competition updated.');
    } catch (e) {
      if (!mounted) return;
      _showMsg(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _delete() async {
    if (_isDeleting) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete competition'),
        content: const Text(
          'This will permanently remove the competition and its data. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(competitionRepositoryProvider).deleteCompetition(widget.competitionId);
      if (!mounted) return;
      _showMsg('Competition deleted.');
      context.go(HomePage.routePath);
    } catch (e) {
      if (!mounted) return;
      _showMsg(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _toggle(int i) {
    setState(() {
      if (_expanded.contains(i)) { _expanded.remove(i); } else { _expanded.add(i); }
    });
  }

  void _addLabel(String v) {
    final t = v.trim();
    if (t.isNotEmpty && !_labels.contains(t)) {
      setState(() { _labels.add(t); _labelCtl.clear(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(competitionDetailsProvider(widget.competitionId));
    final theme = Theme.of(context);

    return AxonScaffold(
      child: state.when(
        loading: () => const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.lg), child: CircularProgressIndicator())),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (competition) {
          _applyData(competition);
          return Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(child: PageHeader(title: 'Manage: ${competition.name}', subtitle: 'Edit all competition settings.')),
                  const SizedBox(width: AppSpacing.md),
                  TextButton(onPressed: () => context.go(CompetitionDashboardPage.routeForId(widget.competitionId)), child: const Text('Back')),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save'),
                  ),
                ]),
                const SizedBox(height: AppSpacing.lg),

                _Sec(index: 0, icon: Icons.emoji_events_outlined, title: 'Basic information', expanded: _expanded, onToggle: () => _toggle(0), children: [
                  AuthTextField(controller: _nameCtl, label: 'Name *', hint: 'Competition name', keyboardType: TextInputType.text, textInputAction: TextInputAction.next, prefixIcon: Icons.emoji_events_outlined, validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(controller: _descCtl, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes_outlined), alignLabelWithHint: true)),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(controller: _dateCtl, readOnly: true, onTap: _pickDate, decoration: const InputDecoration(labelText: 'Launch date', hintText: 'YYYY-MM-DD', prefixIcon: Icon(Icons.calendar_today_outlined))),
                  const SizedBox(height: AppSpacing.md),
                  AuthTextField(controller: _inviteCtl, label: 'Invitation link', hint: 'https://axon.ai/invite/...', keyboardType: TextInputType.url, textInputAction: TextInputAction.done, prefixIcon: Icons.link),
                ]),
                const SizedBox(height: AppSpacing.sm),

                _Sec(index: 1, icon: Icons.article_outlined, title: 'Overview & terms', expanded: _expanded, onToggle: () => _toggle(1), children: [
                  TextFormField(controller: _overviewCtl, maxLines: 8, decoration: const InputDecoration(labelText: 'Overview', alignLabelWithHint: true, border: OutlineInputBorder())),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(controller: _termsCtl, maxLines: 5, decoration: const InputDecoration(labelText: 'Terms & conditions', alignLabelWithHint: true, border: OutlineInputBorder())),
                ]),
                const SizedBox(height: AppSpacing.sm),

                _Sec(index: 2, icon: Icons.dataset_outlined, title: 'Data & evaluation', expanded: _expanded, onToggle: () => _toggle(2), children: [
                  TextFormField(controller: _dataMdCtl, maxLines: 5, decoration: const InputDecoration(labelText: 'Dataset description', alignLabelWithHint: true, border: OutlineInputBorder())),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Image formats', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: ['PNG', 'JPEG', 'SVG'].map((ext) => FilterChip(
                      label: Text(ext),
                      selected: _selectedFormats.contains(ext),
                      onSelected: (sel) => setState(() {
                        if (sel) { _selectedFormats.add(ext); } else { _selectedFormats.remove(ext); }
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(controller: _dataExCtl, decoration: const InputDecoration(labelText: 'Data example URL', prefixIcon: Icon(Icons.link))),
                  const Divider(height: 32),
                  const Text('Evaluation metric', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: ['F1 score', 'Accuracy', 'Precision', 'Recall', 'ROC AUC'].map((m) => FilterChip(
                      label: Text(m),
                      selected: _selectedEvaluation == m,
                      onSelected: (sel) => setState(() => _selectedEvaluation = sel ? m : null),
                    )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Only one metric can be selected.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  const Text('Evaluation protocol', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: 8,
                    children: ['standard', 'loto', 'toto'].map((p) => FilterChip(
                      label: Text(p),
                      selected: _selectedProtocol == p,
                      onSelected: (sel) => setState(() => _selectedProtocol = p),
                    )).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('standard: train/val split, loto: leave-one-task-out, toto: train-on-task-only.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(controller: _scoringExCtl, decoration: const InputDecoration(labelText: 'Scoring example URL', prefixIcon: Icon(Icons.link))),
                ]),
                const SizedBox(height: AppSpacing.sm),

                _Sec(index: 3, icon: Icons.tune_outlined, title: 'Quality settings', expanded: _expanded, onToggle: () => _toggle(3), children: [
                  TextFormField(controller: _maxValCtl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Max validations per image', prefixIcon: Icon(Icons.repeat_outlined))),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(controller: _dupThreshCtl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Duplicate threshold (0–1)', prefixIcon: Icon(Icons.content_copy_outlined))),
                ]),
                const SizedBox(height: AppSpacing.sm),

                _Sec(index: 4, icon: Icons.memory_outlined, title: 'Model submission spec', expanded: _expanded, onToggle: () => _toggle(4), children: [
                  Row(children: [
                    Expanded(child: TextFormField(controller: _modelDirCtl, decoration: const InputDecoration(labelText: 'Model dir', prefixIcon: Icon(Icons.folder_outlined)))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: TextFormField(controller: _dataDirCtl, decoration: const InputDecoration(labelText: 'Data dir', prefixIcon: Icon(Icons.folder_outlined)))),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _infFuncCtl, decoration: const InputDecoration(labelText: 'Inference function', prefixIcon: Icon(Icons.functions_outlined)))),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: TextFormField(controller: _maxSizeMbCtl, decoration: const InputDecoration(labelText: 'Max size (MB)', prefixIcon: Icon(Icons.sd_storage_outlined)))),
                  ]),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(controller: _pyMinCtl, decoration: const InputDecoration(labelText: 'Min Python version', prefixIcon: Icon(Icons.code))),
                  const SizedBox(height: AppSpacing.md),
                  Text('Allowed formats', style: theme.textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(spacing: AppSpacing.sm, children: _formats.keys.map((f) => FilterChip(label: Text(f), selected: _formats[f]!, onSelected: (v) => setState(() => _formats[f] = v))).toList()),
                ]),
                const SizedBox(height: AppSpacing.sm),

                _Sec(index: 5, icon: Icons.label_outlined, title: 'Labels', expanded: _expanded, onToggle: () => _toggle(5), children: [
                  Row(children: [
                    Expanded(child: TextField(controller: _labelCtl, decoration: const InputDecoration(labelText: 'Label name', hintText: 'e.g. cat'), onSubmitted: _addLabel)),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(onPressed: () => _addLabel(_labelCtl.text), child: const Text('Add')),
                  ]),
                  if (_labels.isNotEmpty) const SizedBox(height: AppSpacing.md),
                  Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: _labels.map((l) => Chip(label: Text(l), onDeleted: () => setState(() => _labels.remove(l)))).toList()),
                ]),
                const SizedBox(height: AppSpacing.lg),

                // Danger zone
                Card(
                  color: AppColors.error.withValues(alpha: 0.05),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Danger zone', style: theme.textTheme.titleSmall?.copyWith(color: AppColors.error, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Permanently delete this competition and all its data.', style: theme.textTheme.bodySmall),
                      ])),
                      OutlinedButton.icon(
                        onPressed: _isDeleting ? null : _delete,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          );
        },
      ),
    );
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

class _Sec extends StatelessWidget {
  const _Sec({required this.index, required this.icon, required this.title, required this.expanded, required this.onToggle, required this.children});
  final int index;
  final IconData icon;
  final String title;
  final Set<int> expanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final isOpen = expanded.contains(index);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: theme.colorScheme.primary, size: 18)),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600))),
              AnimatedRotation(turns: isOpen ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: const Icon(Icons.expand_more)),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
          crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ]),
    );
  }
}
