part of 'main.dart';

class BackendClient {
  const BackendClient({
    this.baseUrl = 'http://127.0.0.1:8080',
  });

  final String baseUrl;

  Future<DashboardSnapshot> getState() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/state'));
    return _decodeSnapshot(response);
  }

  Future<DashboardSnapshot> updateState(AppConfigState config) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/v1/state'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(config.toJson()),
    );
    return _decodeSnapshot(response);
  }

  Future<DashboardSnapshot> connect() async {
    final response = await http.post(Uri.parse('$baseUrl/api/v1/connect'));
    return _decodeSnapshot(response);
  }

  Future<DashboardSnapshot> disconnect() async {
    final response = await http.post(Uri.parse('$baseUrl/api/v1/disconnect'));
    return _decodeSnapshot(response);
  }

  Future<bool> getAdminStatus() async {
    final response = await http.get(Uri.parse('$baseUrl/api/v1/admin-status'));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['elevated'] as bool? ?? false;
  }

  Future<void> requestAdmin() async {
    final response =
        await http.post(Uri.parse('$baseUrl/api/v1/request-admin'));
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
  }

  DashboardSnapshot _decodeSnapshot(http.Response response) {
    Map<String, dynamic> body = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } on FormatException {
        body = {'error': response.body};
      }
    }
    if (response.statusCode >= 400) {
      throw Exception((body['error'] ?? response.body).toString());
    }
    return DashboardSnapshot.fromJson(body);
  }
}

class BackendRuntime {
  BackendRuntime(this.backend);

  final BackendClient backend;
  Process? _process;
  bool _launchedByApp = false;
  bool _starting = false;

  Future<void> ensureRunning() async {
    if (await _isReachable()) {
      return;
    }
    if (_starting) {
      await _waitUntilReachable();
      return;
    }

    _starting = true;
    try {
      if (await _isReachable()) {
        return;
      }

      final executable = await _findBackendExecutable();
      if (executable == null) {
        throw Exception(
          'core-manager not found. Build it first or place it next to the app.',
        );
      }

      _process = await Process.start(
        executable.path,
        const [],
        workingDirectory: executable.parent.path,
        mode: ProcessStartMode.normal,
      );
      _launchedByApp = true;
      unawaited(_process!.stdout.drain<void>());
      unawaited(_process!.stderr.drain<void>());

      await _waitUntilReachable();
    } finally {
      _starting = false;
    }
  }

  Future<void> dispose() async {
    if (_launchedByApp && _process != null) {
      _process!.kill();
      _process = null;
      _launchedByApp = false;
    }
  }

  Future<bool> _isReachable() async {
    try {
      await backend.getState();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _waitUntilReachable() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (await _isReachable()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    throw Exception('Backend did not start on http://127.0.0.1:8080');
  }

  Future<File?> _findBackendExecutable() async {
    final executableName =
        Platform.isWindows ? 'core-manager.exe' : 'core-manager';
    final appDirs = <String>{
      File(Platform.resolvedExecutable).parent.path,
      File(Platform.executable).parent.path,
      Directory.current.path,
    };
    final candidates = <String>[
      for (final appDir in appDirs) _joinPath(appDir, executableName),
      for (final appDir in appDirs) _joinPath(appDir, 'data', executableName),
      _joinPath(Directory.current.path, '..', 'dist', 'linux', executableName),
      _joinPath(Directory.current.path, 'dist', 'linux', executableName),
      _joinPath(
          Directory.current.path, '..', 'core_manager', 'bin', executableName),
      _joinPath(Directory.current.path, 'core_manager', 'bin', executableName),
    ];

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    }

    return null;
  }
}

String _joinPath(String first,
    [String? second, String? third, String? fourth, String? fifth]) {
  final parts = <String>[
    first,
    if (second != null) second,
    if (third != null) third,
    if (fourth != null) fourth,
    if (fifth != null) fifth,
  ];
  return parts.join(Platform.pathSeparator);
}
