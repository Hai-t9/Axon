import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/validation/validators.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../widgets/auth/auth_text_field.dart';
import '../../../widgets/layout/axon_scaffold.dart';
import '../../../widgets/layout/page_header.dart';
import '../state/competition_create_controller.dart';
import '../state/competition_list_controller.dart';
import 'competition_dashboard_page.dart';
import '../../home/presentation/home_page.dart';

class HostCompetitionPage extends ConsumerStatefulWidget {
  const HostCompetitionPage({super.key});

  static const routePath = '/competitions/host';
  static const routeName = 'competition-host';

  @override
  ConsumerState<HostCompetitionPage> createState() =>
      _HostCompetitionPageState();
}

class _HostCompetitionPageState extends ConsumerState<HostCompetitionPage> {
  final _formKey = GlobalKey<FormState>();

  // ── Basic info ──
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _dateCtl = TextEditingController();
  DateTime? _launchDate;

  // ── Overview ──
  final _overviewCtl = TextEditingController();
  final _termsCtl = TextEditingController();

  // ── Data ──
  final _dataMdCtl = TextEditingController();
  final _dataFmtCtl = TextEditingController();
  final _dataExCtl = TextEditingController();

  // ── Evaluation ──
  final _evalCtl = TextEditingController();
  final _scoringExCtl = TextEditingController();

  // ── Settings ──
  final _maxValCtl = TextEditingController();
  final _dupThreshCtl = TextEditingController();

  // ── Labels ──
  final List<String> _labels = [];
  final _labelCtl = TextEditingController();

  // ── Teams ──
  final Map<String, List<String>> _teams = {};
  final _teamNameCtl = TextEditingController();
  final List<String> _pendingEmails = [];
  final _emailCtl = TextEditingController();

  // ── Model spec ──
  final _modelDirCtl = TextEditingController(text: 'model');
  final _dataDirCtl = TextEditingController(text: 'data');
  final _infFuncCtl = TextEditingController(text: 'predict');
  final _maxSizeMbCtl = TextEditingController(text: '500');
  final _pyMinCtl = TextEditingController();

  // Checkboxes for allowed model formats
  final Map<String, bool> _formats = {
    'pytorch': true,
    'tensorflow': true,
    'sklearn': true,
    'keras': true,
    'onnx': true,
  };

  // ── Phase deadlines ──
  final Map<String, DateTime?> _phaseDeadlines = {
    '1': null,
    '2': null,
    '3': null,
    '4': null,
  };
  final Map<String, TextEditingController> _deadlineCtrls = {
    '1': TextEditingController(),
    '2': TextEditingController(),
    '3': TextEditingController(),
    '4': TextEditingController(),
  };

  static const Map<String, String> _phaseLabels = {
    '1': 'Data Collection',
    '2': 'Data Validation',
    '3': 'Model Submission',
    '4': 'Model Evaluation',
  };

  // Expanded sections
  final Set<int> _expanded = {0}; // Basic info open by default

  @override
  void dispose() {
    for (final c in [
      _nameCtl, _descCtl, _dateCtl, _overviewCtl, _termsCtl,
      _dataMdCtl, _dataFmtCtl, _dataExCtl, _evalCtl, _scoringExCtl,
      _maxValCtl, _dupThreshCtl, _modelDirCtl, _dataDirCtl,
      _infFuncCtl, _maxSizeMbCtl, _pyMinCtl, _labelCtl, _teamNameCtl, _emailCtl,
      ..._deadlineCtrls.values,
    ]) {
      c.dispose();
    }
    super.dispose();
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

  Future<void> _pickDeadline(String phase) async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _phaseDeadlines[phase] ?? now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 23))),
    );
    if (t == null || !mounted) return;
    final deadline = DateTime(d.year, d.month, d.day, t.hour, t.minute).toUtc();
    setState(() {
      _phaseDeadlines[phase] = deadline;
      _deadlineCtrls[phase]!.text =
          '${d.year}-${_two(d.month)}-${_two(d.day)}  ${_two(t.hour)}:${_two(t.minute)}';
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState?.validate() != true) {
      _showMsg('Please fix the errors above.', isError: true);
      return;
    }

    try {
      final labelsMap = _labels.isEmpty ? null : { for (var l in _labels) l: {} };
      final modelSpecMap = {
        'required_files': ['Dockerfile', 'inference.py', 'requirements.txt'],
        'model_dir': _modelDirCtl.text.trim(),
        'data_dir': _dataDirCtl.text.trim(),
        'inference_function': _infFuncCtl.text.trim(),
        'allowed_model_formats': _formats.entries.where((e) => e.value).map((e) => e.key).toList(),
        'max_size_mb': double.tryParse(_maxSizeMbCtl.text.trim()) ?? 500.0,
        if (_pyMinCtl.text.trim().isNotEmpty) 'python_version_min': _pyMinCtl.text.trim(),
      };

      final deadlines = <String, String>{};
      for (final e in _phaseDeadlines.entries) {
        if (e.value != null) {
          deadlines[e.key] = e.value!.toUtc().toIso8601String();
        }
      }

      final comp =
          await ref.read(competitionCreateProvider.notifier).createCompetition(
                name: _nameCtl.text,
                description: _descCtl.text.trim().isEmpty ? null : _descCtl.text.trim(),
                launchDate: _launchDate,
                overview: _overviewCtl.text.trim().isEmpty ? null : _overviewCtl.text.trim(),
                termsConditions: _termsCtl.text.trim().isEmpty ? null : _termsCtl.text.trim(),
                dataMarkdown: _dataMdCtl.text.trim().isEmpty ? null : _dataMdCtl.text.trim(),
                dataFormat: _dataFmtCtl.text.trim().isEmpty ? null : _dataFmtCtl.text.trim(),
                dataExample: _dataExCtl.text.trim().isEmpty ? null : _dataExCtl.text.trim(),
                evaluation: _evalCtl.text.trim().isEmpty ? null : _evalCtl.text.trim(),
                scoringExample: _scoringExCtl.text.trim().isEmpty ? null : _scoringExCtl.text.trim(),
                maxValidations: int.tryParse(_maxValCtl.text.trim()),
                duplicateThreshold: double.tryParse(_dupThreshCtl.text.trim()),
                labels: labelsMap,
                modelSpec: modelSpecMap,
                teamsData: _teams,
                phaseDeadlines: deadlines.isEmpty ? null : deadlines,
              );
      if (!mounted || comp == null) return;
      _showMsg('Competition created!');
      context.go(CompetitionDashboardPage.routeForId(comp.id));
      Future.microtask(() async {
        try { await ref.read(competitionListProvider.notifier).refreshList(); } catch (_) {}
      });
    } catch (e) {
      if (!mounted) return;
      _showMsg(e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(competitionCreateProvider).isLoading;
    final theme = Theme.of(context);

    return AxonScaffold(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────
            Row(
              children: [
                Expanded(
                  child: PageHeader(
                    title: 'Host a competition',
                    subtitle: 'Configure your competition before launching.',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go(HomePage.routePath),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: isLoading ? null : _submit,
                  icon: isLoading
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.rocket_launch_outlined, size: 18),
                  label: const Text('Launch'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // ── Sections ───────────────────────────
            _Section(
              index: 0,
              icon: Icons.emoji_events_outlined,
              title: 'Basic information',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(0)),
              children: [
                AuthTextField(
                  controller: _nameCtl,
                  label: 'Competition name *',
                  hint: 'Axon Label Sprint 2025',
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  prefixIcon: Icons.emoji_events_outlined,
                  validator: Validators.competitionName,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _descCtl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'A short summary visible on the competition card.',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _dateCtl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: const InputDecoration(
                    labelText: 'Launch date (optional)',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _Section(
              index: 1,
              icon: Icons.article_outlined,
              title: 'Overview & terms',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(1)),
              children: [
                TextFormField(
                  controller: _overviewCtl,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Competition overview (optional)',
                    hintText: 'Full description, supports markdown...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _termsCtl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Terms & conditions (optional)',
                    hintText: 'Rules participants must accept...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _Section(
              index: 2,
              icon: Icons.dataset_outlined,
              title: 'Data & evaluation',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(2)),
              children: [
                TextFormField(
                  controller: _dataMdCtl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Dataset description (optional)',
                    hintText: 'Source, size, structure...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _dataFmtCtl,
                  decoration: const InputDecoration(
                    labelText: 'Data format (optional)',
                    hintText: 'e.g. JPEG 224×224 RGB',
                    prefixIcon: Icon(Icons.data_object),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _dataExCtl,
                  decoration: const InputDecoration(
                    labelText: 'Data example URL (optional)',
                    hintText: 'https://example.com/sample.zip',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
                const Divider(height: 32),
                TextFormField(
                  controller: _evalCtl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Evaluation criteria (optional)',
                    hintText: 'F1 score, accuracy, etc...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _scoringExCtl,
                  decoration: const InputDecoration(
                    labelText: 'Scoring example URL (optional)',
                    hintText: 'https://example.com/scoring.py',
                    prefixIcon: Icon(Icons.link),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _Section(
              index: 3,
              icon: Icons.tune_outlined,
              title: 'Quality settings',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(3)),
              children: [
                TextFormField(
                  controller: _maxValCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Max validations per image (optional)',
                    hintText: 'e.g. 3',
                    prefixIcon: Icon(Icons.repeat_outlined),
                    helperText: 'How many times each image must be validated.',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) return 'Must be a positive integer.';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _dupThreshCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Duplicate threshold (optional)',
                    hintText: 'e.g. 0.95',
                    prefixIcon: Icon(Icons.content_copy_outlined),
                    helperText: 'Similarity score 0–1 above which images are flagged.',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0 || n > 1) return 'Must be 0–1.';
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _Section(
              index: 4,
              icon: Icons.memory_outlined,
              title: 'Model submission spec',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(4)),
              children: [
                Text(
                  'Define what participants must include in their Docker submission.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _modelDirCtl,
                        decoration: const InputDecoration(
                          labelText: 'Model directory',
                          hintText: 'model',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _dataDirCtl,
                        decoration: const InputDecoration(
                          labelText: 'Data directory',
                          hintText: 'data',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _infFuncCtl,
                        decoration: const InputDecoration(
                          labelText: 'Inference function',
                          hintText: 'predict',
                          prefixIcon: Icon(Icons.functions_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: TextFormField(
                        controller: _maxSizeMbCtl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Max size (MB)',
                          hintText: '500',
                          prefixIcon: Icon(Icons.sd_storage_outlined),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _pyMinCtl,
                  decoration: const InputDecoration(
                    labelText: 'Min Python version (optional)',
                    hintText: 'e.g. 3.9',
                    prefixIcon: Icon(Icons.code),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Allowed model formats',
                    style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: _formats.keys.map((fmt) {
                    return FilterChip(
                      label: Text(fmt),
                      selected: _formats[fmt]!,
                      onSelected: (v) => setState(() => _formats[fmt] = v),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _Section(
              index: 5,
              icon: Icons.label_outlined,
              title: 'Labels',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(5)),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _labelCtl,
                        decoration: const InputDecoration(
                          labelText: 'Label name',
                          hintText: 'e.g. cat',
                        ),
                        onSubmitted: _addLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () => _addLabel(_labelCtl.text),
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (_labels.isNotEmpty) const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: _labels.map((l) {
                    return Chip(
                      label: Text(l),
                      onDeleted: () => setState(() => _labels.remove(l)),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _Section(
              index: 6,
              icon: Icons.group_outlined,
              title: 'Teams',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(6)),
              children: [
                Text(
                  'Add teams and their members. Add one email at a time.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _teamNameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Team Name',
                    hintText: 'Team Alpha',
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtl,
                        decoration: const InputDecoration(
                          labelText: 'Member email',
                          hintText: 'alice@example.com',
                        ),
                        onSubmitted: (_) => _addEmail(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: _addEmail,
                      child: const Text('Add'),
                    ),
                  ],
                ),
                if (_pendingEmails.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: _pendingEmails.map((e) {
                      return Chip(
                        label: Text(e),
                        onDeleted: () => setState(() => _pendingEmails.remove(e)),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ElevatedButton.icon(
                  onPressed: _pendingEmails.isEmpty ? null : _addTeam,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: Text('Add Team with ${_pendingEmails.length} member${_pendingEmails.length == 1 ? '' : 's'}'),
                ),

                if (_teams.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Divider(),
                  const SizedBox(height: AppSpacing.sm),
                  ..._teams.entries.map((e) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: ListTile(
                        title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(e.value.join(', ')),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => setState(() => _teams.remove(e.key)),
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _Section(
              index: 7,
              icon: Icons.schedule_outlined,
              title: 'Phase deadlines (optional)',
              expanded: _expanded,
              onToggle: () => setState(() => _toggle(7)),
              children: [
                Text(
                  'Set deadlines for each phase. Phases without a deadline will not enforce a time limit.',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                ..._phaseLabels.entries.map((e) {
                  final phase = e.key;
                  final label = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: TextFormField(
                      controller: _deadlineCtrls[phase],
                      readOnly: true,
                      onTap: () => _pickDeadline(phase),
                      decoration: InputDecoration(
                        labelText: 'Phase $phase: $label',
                        hintText: 'Set deadline...',
                        prefixIcon: const Icon(Icons.calendar_month_outlined),
                        suffixIcon: _phaseDeadlines[phase] != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () => setState(() {
                                  _phaseDeadlines[phase] = null;
                                  _deadlineCtrls[phase]!.clear();
                                }),
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _addLabel(String value) {
    final v = value.trim();
    if (v.isNotEmpty && !_labels.contains(v)) {
      setState(() {
        _labels.add(v);
        _labelCtl.clear();
      });
    }
  }

  void _addEmail() {
    final v = _emailCtl.text.trim().toLowerCase();
    if (v.isNotEmpty && !_pendingEmails.contains(v)) {
      setState(() {
        _pendingEmails.add(v);
        _emailCtl.clear();
      });
    }
  }

  void _addTeam() {
    final name = _teamNameCtl.text.trim();
    if (name.isNotEmpty && _pendingEmails.isNotEmpty) {
      setState(() {
        _teams[name] = List.from(_pendingEmails);
        _teamNameCtl.clear();
        _pendingEmails.clear();
      });
    }
  }

  void _toggle(int i) {
    if (_expanded.contains(i)) {
      _expanded.remove(i);
    } else {
      _expanded.add(i);
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');
}

// ── Collapsible section card ───────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({
    required this.index,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.children,
  });

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
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: theme.colorScheme.primary, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
            crossFadeState:
                isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}
