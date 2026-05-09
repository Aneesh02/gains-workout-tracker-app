import 'dart:convert';
import 'package:http/http.dart' as http;

class GitHubRepo {
  final String name;
  final String fullName;
  final String owner;
  final bool private;
  final String? description;

  const GitHubRepo({
    required this.name,
    required this.fullName,
    required this.owner,
    required this.private,
    this.description,
  });

  factory GitHubRepo.fromJson(Map<String, dynamic> j) => GitHubRepo(
        name: j['name'] as String,
        fullName: j['full_name'] as String,
        owner: (j['owner'] as Map<String, dynamic>)['login'] as String,
        private: j['private'] as bool,
        description: j['description'] as String?,
      );
}

class GitHubAuthService {
  static const patCreateUrl =
      'https://github.com/settings/personal-access-tokens/new'
      '?description=Gains+Workout+Tracker'
      '&default_expires_at=never'
      '&default_permissions%5Bcontents%5D=write';

  static Map<String, String> _headers(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  /// Returns username on success, null if token is invalid.
  Future<String?> validateToken(String token) async {
    try {
      final res = await http
          .get(Uri.parse('https://api.github.com/user'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return (jsonDecode(res.body) as Map<String, dynamic>)['login'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<GitHubRepo>> listRepos(String token) async {
    final repos = <GitHubRepo>[];
    int page = 1;
    while (true) {
      final res = await http
          .get(
            Uri.parse(
                'https://api.github.com/user/repos?type=owner&sort=updated&per_page=100&page=$page'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) break;
      final list = jsonDecode(res.body) as List;
      if (list.isEmpty) break;
      repos.addAll(
          list.map((j) => GitHubRepo.fromJson(j as Map<String, dynamic>)));
      if (list.length < 100) break;
      page++;
    }
    return repos;
  }

  Future<GitHubRepo> createRepo(
    String token, {
    required String name,
    bool private = true,
    String description = 'Gains workout history',
  }) async {
    final res = await http
        .post(
          Uri.parse('https://api.github.com/user/repos'),
          headers: {
            ..._headers(token),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'name': name,
            'description': description,
            'private': private,
            'auto_init': true,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 201) {
      return GitHubRepo.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    final err = jsonDecode(res.body) as Map<String, dynamic>;
    throw Exception(
        err['message'] ?? 'Failed to create repo (${res.statusCode})');
  }
}
