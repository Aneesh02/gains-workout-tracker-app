import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/workout_provider.dart';
import '../services/github_auth_service.dart';
import '../services/github_sync_service.dart';
import '../theme/app_theme.dart';

enum _Step { idle, requesting, polling, pickRepo, creating }

class GitHubConnectScreen extends StatefulWidget {
  const GitHubConnectScreen({super.key});

  @override
  State<GitHubConnectScreen> createState() => _GitHubConnectScreenState();
}

class _GitHubConnectScreenState extends State<GitHubConnectScreen> {
  final _authSvc = GitHubAuthService();
  final _syncSvc = GitHubSyncService();

  _Step _step = _Step.idle;
  String _error = '';

  // Device flow
  DeviceFlowStart? _flow;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _pollInterval = 5;
  int _remaining = 900;

  // Auth result
  String _token = '';
  String _username = '';

  // Repo picker
  List<GitHubRepo> _repos = [];
  bool _loadingRepos = false;
  String _repoSearch = '';
  final _searchCtrl = TextEditingController();

  // Repo creation
  final _repoNameCtrl = TextEditingController();
  bool _privateRepo = true;
  bool _creating = false;
  String _createError = '';

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _searchCtrl.dispose();
    _repoNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _startAuth() async {
    setState(() {
      _step = _Step.requesting;
      _error = '';
    });
    try {
      final flow = await _authSvc.startDeviceFlow();
      _flow = flow;
      _pollInterval = flow.interval;
      _remaining = flow.expiresIn;
      setState(() => _step = _Step.polling);
      _startPolling();
      _startCountdown();
    } catch (e) {
      setState(() {
        _step = _Step.idle;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(Duration(seconds: _pollInterval), (_) async {
      if (_flow == null) return;
      final result = await _authSvc.pollForToken(
        deviceCode: _flow!.deviceCode,
        interval: _pollInterval,
      );
      if (!mounted) return;

      switch (result) {
        case DeviceFlowPending():
          break;
        case DeviceFlowSlowDown(:final newInterval):
          _pollInterval = newInterval;
          _startPolling();
        case DeviceFlowSuccess(:final accessToken):
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          _token = accessToken;
          await _syncSvc.savePat(_token);
          unawaited(_loadRepos());
        case DeviceFlowFailed(:final error):
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() {
            _step = _Step.idle;
            _error = error;
          });
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _countdownTimer?.cancel();
          _pollTimer?.cancel();
          _step = _Step.idle;
          _error = 'Code expired. Please try again.';
        }
      });
    });
  }

  Future<void> _loadRepos() async {
    setState(() {
      _loadingRepos = true;
      _step = _Step.pickRepo;
    });
    final username = await _authSvc.getUsername(_token);
    if (username != null) _username = username;
    final repos = await _authSvc.listRepos(_token);
    if (mounted) setState(() {
      _repos = repos;
      _loadingRepos = false;
    });
  }

  void _selectRepo(GitHubRepo repo) {
    final provider = context.read<WorkoutProvider>();
    provider.updateGymSettings(provider.gymSettings.copyWith(
      githubOwner: repo.owner,
      githubRepo: repo.name,
      githubBranch: 'main',
      githubUsername: _username,
    ));
    Navigator.pop(context, true);
  }

  Future<void> _createRepo() async {
    final name = _repoNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _createError = 'Enter a repo name');
      return;
    }
    setState(() {
      _creating = true;
      _createError = '';
    });
    try {
      final repo = await _authSvc.createRepo(
        _token,
        name: name,
        private: _privateRepo,
      );
      if (mounted) _selectRepo(repo);
    } catch (e) {
      if (mounted) {
        setState(() {
          _creating = false;
          _createError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          _step == _Step.pickRepo || _step == _Step.creating
              ? 'Choose Repository'
              : 'Connect GitHub',
          style: const TextStyle(
              color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textSecondary),
        elevation: 0,
        actions: _step == _Step.pickRepo
            ? [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _step = _Step.creating;
                    _createError = '';
                    _repoNameCtrl.text = 'gains-vault';
                  }),
                  icon: const Icon(Icons.add, size: 18, color: AppColors.blue),
                  label: const Text('New',
                      style: TextStyle(color: AppColors.blue, fontSize: 14)),
                ),
              ]
            : null,
      ),
      body: switch (_step) {
        _Step.idle || _Step.requesting => _buildIdleBody(),
        _Step.polling => _buildPollingBody(),
        _Step.pickRepo => _buildRepoPicker(),
        _Step.creating => _buildCreateRepo(),
      },
    );
  }

  Widget _buildIdleBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.cloud_outlined,
                  color: AppColors.blue, size: 40),
            ),
            const SizedBox(height: 24),
            const Text('Connect to GitHub',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Sync your workouts as markdown files to any GitHub repository. Your data stays in your own repo.',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error,
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _step == _Step.requesting ? null : _startAuth,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _step == _Step.requesting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Sign in with GitHub',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPollingBody() {
    final mins = _remaining ~/ 60;
    final secs = _remaining % 60;
    final timeStr =
        '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Authorize in GitHub',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              '1. Open ${_flow?.verificationUri ?? 'github.com/login/device'}\n2. Enter this code:',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.6),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: _flow?.userCode ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: AppColors.blue.withOpacity(0.4), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _flow?.userCode ?? '',
                      style: const TextStyle(
                        color: AppColors.blue,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.copy,
                        color: AppColors.textSecondary, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final uri =
                      Uri.parse(_flow?.verificationUri ?? 'https://github.com/login/device');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.open_in_browser, size: 20),
                label: const Text('Open github.com',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.blue),
                ),
                const SizedBox(width: 10),
                Text(
                  'Waiting · expires $timeStr',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                _pollTimer?.cancel();
                _countdownTimer?.cancel();
                setState(() {
                  _step = _Step.idle;
                  _error = '';
                });
              },
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepoPicker() {
    final filtered = _repos.where((r) {
      if (_repoSearch.isEmpty) return true;
      return r.name.toLowerCase().contains(_repoSearch.toLowerCase()) ||
          r.fullName.toLowerCase().contains(_repoSearch.toLowerCase());
    }).toList();

    return Column(
      children: [
        if (_username.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              const Icon(Icons.check_circle,
                  color: AppColors.checkGreen, size: 16),
              const SizedBox(width: 6),
              Text('Signed in as @$_username',
                  style: const TextStyle(
                      color: AppColors.checkGreen, fontSize: 13)),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _repoSearch = v),
            style:
                const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search repositories...',
              hintStyle: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  color: AppColors.textSecondary, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingRepos
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.blue))
              : ListView(
                  children: [
                    if (_repoSearch.isEmpty)
                      ListTile(
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add,
                              color: AppColors.blue, size: 20),
                        ),
                        title: const Text('Create new repository',
                            style: TextStyle(
                                color: AppColors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        subtitle: const Text(
                            'Start fresh with a dedicated repo',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12)),
                        onTap: () => setState(() {
                          _step = _Step.creating;
                          _createError = '';
                          _repoNameCtrl.text = 'gains-vault';
                        }),
                      ),
                    if (_repoSearch.isEmpty && _repos.isNotEmpty)
                      const Divider(height: 1, color: AppColors.divider),
                    if (filtered.isEmpty && _repoSearch.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(children: [
                          const Icon(Icons.folder_off_outlined,
                              color: AppColors.textSecondary, size: 40),
                          const SizedBox(height: 12),
                          Text('No repos matching "$_repoSearch"',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14),
                              textAlign: TextAlign.center),
                        ]),
                      ),
                    ...filtered.map((repo) => Column(children: [
                          ListTile(
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                repo.private
                                    ? Icons.lock_outline
                                    : Icons.folder_outlined,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                            ),
                            title: Text(repo.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500)),
                            subtitle: Text(
                              repo.private ? 'Private' : 'Public',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12),
                            ),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.textSecondary, size: 20),
                            onTap: () => _selectRepo(repo),
                          ),
                          const Divider(
                              height: 1,
                              indent: 56,
                              color: AppColors.divider),
                        ])),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildCreateRepo() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _step = _Step.pickRepo),
            icon: const Icon(Icons.arrow_back,
                size: 16, color: AppColors.textSecondary),
            label: const Text('Back to repos',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
          ),
          const SizedBox(height: 20),
          const Text('New Repository',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Create a new GitHub repo to store your workout notes.',
            style:
                TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          const Text('Repository name',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _repoNameCtrl,
            autofocus: true,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'gains-vault',
              hintStyle:
                  const TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.blue),
              ),
              errorText: _createError.isNotEmpty ? _createError : null,
              errorStyle: const TextStyle(color: AppColors.red),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Private repository',
                      style: TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Only you can see this repository',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: _privateRepo,
              onChanged: (v) => setState(() => _privateRepo = v),
              activeColor: AppColors.blue,
            ),
          ]),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _creating ? null : _createRepo,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create & Connect',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
