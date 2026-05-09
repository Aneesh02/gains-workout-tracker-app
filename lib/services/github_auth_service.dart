import 'dart:convert';
import 'package:http/http.dart' as http;

class DeviceFlowStart {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int interval;
  final int expiresIn;

  const DeviceFlowStart({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresIn,
  });
}

sealed class DeviceFlowResult {}

class DeviceFlowPending extends DeviceFlowResult {}

class DeviceFlowSlowDown extends DeviceFlowResult {
  final int newInterval;
  DeviceFlowSlowDown(this.newInterval);
}

class DeviceFlowSuccess extends DeviceFlowResult {
  final String accessToken;
  DeviceFlowSuccess(this.accessToken);
}

class DeviceFlowFailed extends DeviceFlowResult {
  final String error;
  DeviceFlowFailed(this.error);
}

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
  // Register a GitHub OAuth App at:
  // https://github.com/settings/developers → OAuth Apps → New OAuth App
  // Enable "Device Flow", set Homepage URL to anything (e.g. https://github.com).
  // Paste the client_id here.
  static const clientId = 'YOUR_GITHUB_OAUTH_CLIENT_ID';

  static const _scope = 'repo';

  static Map<String, String> _apiHeaders(String token) => {
        'Authorization': 'Bearer $token',
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
      };

  Future<DeviceFlowStart> startDeviceFlow() async {
    final res = await http
        .post(
          Uri.parse('https://github.com/login/device/code'),
          headers: {'Accept': 'application/json'},
          body: {'client_id': clientId, 'scope': _scope},
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Device flow start failed (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data.containsKey('error')) {
      throw Exception(data['error_description'] ?? data['error']);
    }

    return DeviceFlowStart(
      deviceCode: data['device_code'] as String,
      userCode: data['user_code'] as String,
      verificationUri: data['verification_uri'] as String,
      interval: (data['interval'] as num?)?.toInt() ?? 5,
      expiresIn: (data['expires_in'] as num?)?.toInt() ?? 900,
    );
  }

  Future<DeviceFlowResult> pollForToken({
    required String deviceCode,
    required int interval,
  }) async {
    final res = await http
        .post(
          Uri.parse('https://github.com/login/oauth/access_token'),
          headers: {'Accept': 'application/json'},
          body: {
            'client_id': clientId,
            'device_code': deviceCode,
            'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) return DeviceFlowFailed('HTTP ${res.statusCode}');

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final error = data['error'] as String?;

    if (error == null) {
      final token = data['access_token'] as String?;
      if (token != null && token.isNotEmpty) return DeviceFlowSuccess(token);
      return DeviceFlowFailed('No token in response');
    }

    return switch (error) {
      'authorization_pending' => DeviceFlowPending(),
      'slow_down' => DeviceFlowSlowDown(interval + 5),
      'expired_token' => DeviceFlowFailed('Code expired. Please try again.'),
      'access_denied' => DeviceFlowFailed('Access denied.'),
      _ => DeviceFlowFailed(data['error_description'] as String? ?? error),
    };
  }

  Future<String?> getUsername(String token) async {
    try {
      final res = await http
          .get(
            Uri.parse('https://api.github.com/user'),
            headers: _apiHeaders(token),
          )
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
            headers: _apiHeaders(token),
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
            ..._apiHeaders(token),
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
