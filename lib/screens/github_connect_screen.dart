import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/workout_provider.dart';
import '../services/github_auth_service.dart';
import '../services/github_sync_service.dart';
import '../theme/app_theme.dart';

enum _Step { idle, pickRepo, creating }

class GitHubConnectScreen extends StatefulWidget {
  const GitHubConnectScreen({super.key});

  @override
  State<GitHubConnectScreen> createState() => _GitHubConnectScreenState();
}

class _GitHubConnectScreenState extends State<GitHubConnectScreen> {
  final _authSvc = GitHubAuthService();
  final _syncSvc = GitHubSyncService();

  _Step _step = _Step.idle;

  // Token input
  final _tokenCtrl = TextEditingController();
  bool _obscure = true;
  bool _validating = false;
  String _tokenError = '';

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
    _tokenCtrl.dispose();
    _searchCtrl.dispose();
    _repoNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _tokenError = 'Paste your token here');
      return;
    }
    setState(() {
      _validating = true;
      _tokenError = '';
    });

    final username = await _authSvc.validateToken(token);
    if (!mounted) return;

    if (username == null) {
      setState(() {
        _validating = false;
        _tokenError = 'Invalid token — check it and try again';
      });
      return;
    }

    _token = token;
    _username = username;
    await _syncSvc.savePat(token);

    setState(() {
      _validating = false;
      _loadingRepos = true;
      _step = _Step.pickRepo;
    });

    final repos = await _authSvc.listRepos(token);
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
      if (mounted) setState(() {
        _creating = false;
        _createError = e.toString().replaceFirst('Exception: ', '');
      });
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
        _Step.idle => _buildIdle(),
        _Step.pickRepo => _buildRepoPicker(),
        _Step.creating => _buildCreateRepo(),
      },
    );
  }

  Widget _buildIdle() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── Step 1: create token ──────────────────────────────────────
        _stepHeader('1', 'Create a token on GitHub'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A fine-grained token scoped only to your workout repo — nothing else.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),
              _instruction(Icons.settings_outlined, 'Token type', 'Fine-grained personal access token'),
              const SizedBox(height: 10),
              _instruction(Icons.folder_outlined, 'Repository access', 'Only select repositories → your workout repo\n(or All repositories if you haven\'t created it yet)'),
              const SizedBox(height: 10),
              _instruction(Icons.edit_outlined, 'Permissions', 'Contents → Read and Write\n(everything else: No access)'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(GitHubAuthService.patCreateUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.open_in_browser, size: 18),
                  label: const Text('Open GitHub → Create Token',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Step 2: paste token ───────────────────────────────────────
        _stepHeader('2', 'Paste your token'),
        const SizedBox(height: 12),
        TextField(
          controller: _tokenCtrl,
          obscureText: _obscure,
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 14, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'github_pat_...',
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.blue),
            ),
            errorText: _tokenError.isNotEmpty ? _tokenError : null,
            errorStyle: const TextStyle(color: AppColors.red),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onSubmitted: (_) => _connect(),
        ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _validating ? null : _connect,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.blue,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _validating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Connect',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _stepHeader(String number, String label) {
    return Row(children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.blue,
          borderRadius: BorderRadius.circular(99),
        ),
        alignment: Alignment.center,
        child: Text(number,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _instruction(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.blue),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, height: 1.5),
              children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600)),
                TextSpan(
                    text: value,
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ),
      ],
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
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14),
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
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
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
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
