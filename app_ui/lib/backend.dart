part of 'main.dart';

/// Local HTTP API for core-manager (avoid 8080 — common dev/proxy conflicts).
const int kBackendPort = 29452;
const String kBackendBaseUrl = 'http://127.0.0.1:$kBackendPort';

class BackendClient {
  const BackendClient({
    this.baseUrl = kBackendBaseUrl,
  });

  final String baseUrl;
  static const Duration _stateTimeout = Duration(seconds: 10);
  static const Duration _updateStateTimeout = Duration(seconds: 25);
  static const Duration _connectTimeout = Duration(seconds: 90);

  static final http.Client _client = IOClient(_createDirectHttpClient());

  static HttpClient _createDirectHttpClient() {
    final client = HttpClient();
    client.findProxy = (_) => 'DIRECT';
    return client;
  }

  Future<DashboardSnapshot> getState() async {
    final response = await _client
        .get(Uri.parse('$baseUrl/api/v1/state'))
        .timeout(_stateTimeout);
    return _decodeSnapshot(response);
  }

  Future<DashboardSnapshot> updateState(AppConfigState config) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/api/v1/state'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(config.toJson()),
        )
        .timeout(_updateStateTimeout);
    return _decodeSnapshot(response, acceptServiceUnavailable: true);
  }

  Future<DashboardSnapshot> connect() async {
    final response = await _client
        .post(Uri.parse('$baseUrl/api/v1/connect'))
        .timeout(_connectTimeout);
    return _decodeSnapshot(response, acceptServiceUnavailable: true);
  }

  Future<DashboardSnapshot> warmRoutingAssets() async {
    final response = await _client
        .post(Uri.parse('$baseUrl/api/v1/routing-assets/warm'))
        .timeout(_stateTimeout);
    return _decodeSnapshot(response);
  }

  Future<DashboardSnapshot> disconnect() async {
    final response = await _client
        .post(Uri.parse('$baseUrl/api/v1/disconnect'))
        .timeout(_connectTimeout);
    return _decodeSnapshot(response);
  }

  Future<void> shutdown() async {
    final response = await _client
        .post(Uri.parse('$baseUrl/api/v1/shutdown'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
  }

  Future<bool> getAdminStatus() async {
    final response =
        await _client.get(Uri.parse('$baseUrl/api/v1/admin-status'));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['elevated'] as bool? ?? false;
  }

  Future<void> requestAdmin([String? password]) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/request-admin'),
      headers: password == null ? null : {'Content-Type': 'application/json'},
      body: password == null ? null : jsonEncode({'password': password}),
    );
    if (response.statusCode >= 400) {
      throw Exception(response.body);
    }
  }

  DashboardSnapshot _decodeSnapshot(
    http.Response response, {
    bool acceptServiceUnavailable = false,
  }) {
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
    if (response.statusCode == 503 && acceptServiceUnavailable) {
      return DashboardSnapshot.fromJson(body);
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
  bool _disposed = false;

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
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_launchedByApp && _process != null) {
      try {
        if (await _isReachable()) {
          await backend.shutdown();
        }
      } catch (_) {
        // Fallback to process kill below if graceful shutdown is unavailable.
      }

      try {
        final exitCode = _process!.exitCode;
        await exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        _process!.kill();
      } finally {
        _process = null;
        _launchedByApp = false;
      }
    }
    if (Platform.isWindows) {
      try {
        Process.runSync('taskkill', ['/F', '/IM', 'core-manager.exe', '/T'],
            runInShell: true);
        Process.runSync('taskkill', ['/F', '/IM', 'xray.exe', '/T'],
            runInShell: true);
      } catch (_) {}
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
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    throw Exception('Backend did not start on $kBackendBaseUrl');
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
