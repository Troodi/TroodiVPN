import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const TroodiVpnApp());
}

class TroodiVpnApp extends StatelessWidget {
  const TroodiVpnApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Troodi VPN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppPalette.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppPalette.bg1,
        fontFamily: 'Segoe UI',
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withValues(alpha: 0.84),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: AppUi.primaryButton(),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: AppUi.outlinedButton(),
        ),
        segmentedButtonTheme: SegmentedButtonThemeData(
          style: AppUi.segmentedButton(),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return Colors.white;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppPalette.blueDark;
            }
            return const Color(0xFFD1D4DD);
          }),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppPalette.inputFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

enum ConnectionStateValue { connected, disconnected }

enum RoutingMode { global, whitelist, blacklist }

enum DnsMode { auto, proxy, direct }

enum ProfileHealth { healthy, testing, offline }

enum AppPage { home, rules, profiles, settings }

enum TunnelMode { vpn, proxy }

class AppPalette {
  static const bg0 = Color(0xFFF0F1F4);
  static const bg1 = Color(0xFFE6E7EB);
  static const bg2 = Color(0xFFDADCE2);
  static const homeBgTop = Color(0xFF1B2141);
  static const homeBgMid = Color(0xFF11172F);
  static const homeBgBottom = Color(0xFF090D1C);
  static const homeText = Color(0xFFE3E7F6);
  static const homeTextMuted = Color(0xFFA1A8C3);
  static const homeAccent = Color(0xFF6474D9);
  static const homeAccentStrong = Color(0xFF5968CB);
  static const homeGlass = Color(0x171A2F52);
  static const homeGlassStrong = Color(0x22314574);
  static const card = Colors.white;
  static const inputFill = Color(0xFFF7F8FA);
  static const blue = Color(0xFF4F74DA);
  static const blueSoft = Color(0xFF6C7FF0);
  static const blueDark = Color(0xFF4B72DF);
  static const text = Color(0xFF222222);
  static const textMuted = Color(0xFF8D8D8D);
  static const border = Color(0xFFE8E8E8);
}

class AppShadows {
  static final soft = BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 16,
    offset: const Offset(0, 6),
  );

  static final card = BoxShadow(
    color: const Color(0xFF5960A7).withValues(alpha: 0.14),
    blurRadius: 18,
    offset: const Offset(0, 10),
  );

  static BoxShadow glow(Color color) {
    return BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 34,
      spreadRadius: 2,
      offset: const Offset(0, 16),
    );
  }

  static final darkCard = BoxShadow(
    color: const Color(0xFF03050D).withValues(alpha: 0.42),
    blurRadius: 32,
    offset: const Offset(0, 18),
  );
}

class AppUi {
  static ButtonStyle primaryButton([Color bg = AppPalette.blueDark]) {
    return FilledButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static ButtonStyle outlinedButton() {
    return OutlinedButton.styleFrom(
      foregroundColor: AppPalette.text,
      side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static ButtonStyle segmentedButton() {
    return SegmentedButton.styleFrom(
      side: BorderSide(color: AppPalette.blueDark.withValues(alpha: 0.18)),
      backgroundColor: Colors.white.withValues(alpha: 0.56),
      selectedBackgroundColor: AppPalette.blueDark,
      selectedForegroundColor: Colors.white,
      foregroundColor: const Color(0xFF3D4560),
    );
  }

  static ButtonStyle segmentedHeaderButton() {
    return SegmentedButton.styleFrom(
      side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
      backgroundColor: Colors.white.withValues(alpha: 0.14),
      selectedBackgroundColor: Colors.white.withValues(alpha: 0.24),
      selectedForegroundColor: Colors.white,
      foregroundColor: Colors.white,
    );
  }

  static ButtonStyle powerButton(Color color) {
    return IconButton.styleFrom(
      foregroundColor: color,
      shape: const CircleBorder(),
      padding: const EdgeInsets.all(44),
      disabledForegroundColor: const Color(0xFF9AA0AE).withValues(alpha: 0.7),
    );
  }
}

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.latencyMs,
    required this.health,
    required this.protocol,
    this.address = '',
    this.port = 0,
    this.sni = '',
    this.security = '',
    this.transport = '',
    this.alpn = '',
    this.fingerprint = '',
    this.flow = '',
    this.host = '',
    this.path = '',
    this.realityPublicKey = '',
    this.realityShortId = '',
    this.spiderX = '',
    this.userId = '',
    this.password = '',
    this.rawLink = '',
  });

  final String id;
  final String name;
  final int latencyMs;
  final ProfileHealth health;
  final String protocol;
  final String address;
  final int port;
  final String sni;
  final String security;
  final String transport;
  final String alpn;
  final String fingerprint;
  final String flow;
  final String host;
  final String path;
  final String realityPublicKey;
  final String realityShortId;
  final String spiderX;
  final String userId;
  final String password;
  final String rawLink;
}

class AppConfigState {
  const AppConfigState({
    required this.activeProfileId,
    required this.connectionState,
    required this.routingMode,
    required this.dnsMode,
    required this.systemProxyEnabled,
    required this.tunEnabled,
    required this.launchAtStartup,
    required this.proxyDomains,
    required this.directDomains,
    required this.blockedDomains,
    required this.profiles,
  });

  final String activeProfileId;
  final ConnectionStateValue connectionState;
  final RoutingMode routingMode;
  final DnsMode dnsMode;
  final bool systemProxyEnabled;
  final bool tunEnabled;
  final bool launchAtStartup;
  final List<String> proxyDomains;
  final List<String> directDomains;
  final List<String> blockedDomains;
  final List<ServerProfile> profiles;

  factory AppConfigState.fromJson(Map<String, dynamic> json) {
    return AppConfigState(
      activeProfileId: json['activeProfileId'] as String? ?? '',
      connectionState: _connectionFromString(
        json['connectionState'] as String? ?? 'disconnected',
      ),
      routingMode: _routingModeFromString(
        json['routingMode'] as String? ?? 'global',
      ),
      dnsMode: _dnsModeFromString(json['dnsMode'] as String? ?? 'auto'),
      systemProxyEnabled: json['systemProxyEnabled'] as bool? ?? false,
      tunEnabled: json['tunEnabled'] as bool? ?? false,
      launchAtStartup: json['launchAtStartup'] as bool? ?? false,
      proxyDomains: _stringList(json['proxyDomains']),
      directDomains: _stringList(json['directDomains']),
      blockedDomains: _stringList(json['blockedDomains']),
      profiles: (json['profiles'] as List<dynamic>? ?? [])
          .map((item) => _serverProfileFromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  AppConfigState copyWith({
    String? activeProfileId,
    ConnectionStateValue? connectionState,
    RoutingMode? routingMode,
    DnsMode? dnsMode,
    bool? systemProxyEnabled,
    bool? tunEnabled,
    bool? launchAtStartup,
    List<String>? proxyDomains,
    List<String>? directDomains,
    List<String>? blockedDomains,
    List<ServerProfile>? profiles,
  }) {
    return AppConfigState(
      activeProfileId: activeProfileId ?? this.activeProfileId,
      connectionState: connectionState ?? this.connectionState,
      routingMode: routingMode ?? this.routingMode,
      dnsMode: dnsMode ?? this.dnsMode,
      systemProxyEnabled: systemProxyEnabled ?? this.systemProxyEnabled,
      tunEnabled: tunEnabled ?? this.tunEnabled,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      proxyDomains: proxyDomains ?? this.proxyDomains,
      directDomains: directDomains ?? this.directDomains,
      blockedDomains: blockedDomains ?? this.blockedDomains,
      profiles: profiles ?? this.profiles,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeProfileId': activeProfileId,
      'connectionState': connectionState.name,
      'routingMode': routingMode.name,
      'dnsMode': dnsMode.name,
      'systemProxyEnabled': systemProxyEnabled,
      'tunEnabled': tunEnabled,
      'launchAtStartup': launchAtStartup,
      'proxyDomains': proxyDomains,
      'directDomains': directDomains,
      'blockedDomains': blockedDomains,
      'profiles': profiles.map(_serverProfileToJson).toList(),
    };
  }
}

class RuntimeSnapshot {
  const RuntimeSnapshot({
    required this.running,
    required this.pid,
    required this.binaryPath,
    required this.configPath,
    required this.lastError,
    required this.lastExit,
    required this.mode,
    required this.latencyMs,
    required this.elevated,
    required this.logs,
  });

  static const empty = RuntimeSnapshot(
    running: false,
    pid: 0,
    binaryPath: '',
    configPath: '',
    lastError: '',
    lastExit: '',
    mode: 'proxy',
    latencyMs: 0,
    elevated: false,
    logs: <String>[],
  );

  final bool running;
  final int pid;
  final String binaryPath;
  final String configPath;
  final String lastError;
  final String lastExit;
  final String mode;
  final int latencyMs;
  final bool elevated;
  final List<String> logs;

  bool get isSafeTunMode => mode == 'tun' && latencyMs == 0;

  factory RuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return RuntimeSnapshot(
      running: json['running'] as bool? ?? false,
      pid: json['pid'] as int? ?? 0,
      binaryPath: json['binaryPath'] as String? ?? '',
      configPath: json['configPath'] as String? ?? '',
      lastError: json['lastError'] as String? ?? '',
      lastExit: json['lastExit'] as String? ?? '',
      mode: json['mode'] as String? ?? 'proxy',
      latencyMs: json['latencyMs'] as int? ?? 0,
      elevated: json['elevated'] as bool? ?? false,
      logs: _stringList(json['logs']),
    );
  }
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.config,
    required this.runtime,
  });

  final AppConfigState config;
  final RuntimeSnapshot runtime;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) {
    return DashboardSnapshot(
      config: AppConfigState.fromJson(json['config'] as Map<String, dynamic>),
      runtime: RuntimeSnapshot.fromJson(
          json['runtime'] as Map<String, dynamic>? ?? {}),
    );
  }
}

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

ServerProfile _serverProfileFromJson(Map<String, dynamic> json) {
  return ServerProfile(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Unnamed profile',
    latencyMs: json['latencyMs'] as int? ?? 0,
    health: _healthFromString(json['health'] as String? ?? 'offline'),
    protocol: json['protocol'] as String? ?? 'unknown',
    address: json['address'] as String? ?? '',
    port: json['port'] as int? ?? 0,
    sni: json['sni'] as String? ?? '',
    security: json['security'] as String? ?? '',
    transport: json['transport'] as String? ?? '',
    alpn: json['alpn'] as String? ?? '',
    fingerprint: json['fingerprint'] as String? ?? '',
    flow: json['flow'] as String? ?? '',
    host: json['host'] as String? ?? '',
    path: json['path'] as String? ?? '',
    realityPublicKey: json['realityPublicKey'] as String? ?? '',
    realityShortId: json['realityShortId'] as String? ?? '',
    spiderX: json['spiderX'] as String? ?? '',
    userId: json['userId'] as String? ?? '',
    password: json['password'] as String? ?? '',
    rawLink: json['rawLink'] as String? ?? '',
  );
}

Map<String, dynamic> _serverProfileToJson(ServerProfile profile) {
  return {
    'id': profile.id,
    'name': profile.name,
    'latencyMs': profile.latencyMs,
    'health': profile.health.name,
    'protocol': profile.protocol,
    'address': profile.address,
    'port': profile.port,
    'sni': profile.sni,
    'security': profile.security,
    'transport': profile.transport,
    'alpn': profile.alpn,
    'fingerprint': profile.fingerprint,
    'flow': profile.flow,
    'host': profile.host,
    'path': profile.path,
    'realityPublicKey': profile.realityPublicKey,
    'realityShortId': profile.realityShortId,
    'spiderX': profile.spiderX,
    'userId': profile.userId,
    'password': profile.password,
    'rawLink': profile.rawLink,
  };
}

List<String> _stringList(dynamic value) {
  return (value as List<dynamic>? ?? [])
      .map((item) => item.toString())
      .toList();
}

ConnectionStateValue _connectionFromString(String value) {
  return ConnectionStateValue.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ConnectionStateValue.disconnected,
  );
}

RoutingMode _routingModeFromString(String value) {
  return RoutingMode.values.firstWhere(
    (item) => item.name == value,
    orElse: () => RoutingMode.global,
  );
}

DnsMode _dnsModeFromString(String value) {
  return DnsMode.values.firstWhere(
    (item) => item.name == value,
    orElse: () => DnsMode.auto,
  );
}

ProfileHealth _healthFromString(String value) {
  return ProfileHealth.values.firstWhere(
    (item) => item.name == value,
    orElse: () => ProfileHealth.offline,
  );
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BackendClient backend = const BackendClient();
  late final BackendRuntime backendRuntime;
  Timer? pollTimer;
  bool isRefreshing = false;

  ConnectionStateValue connection = ConnectionStateValue.disconnected;
  RoutingMode routingMode = RoutingMode.global;
  DnsMode dnsMode = DnsMode.auto;
  bool systemProxyEnabled = true;
  bool tunEnabled = false;
  bool launchAtStartup = true;
  AppPage selectedPage = AppPage.home;
  bool isLoading = true;
  bool isBusy = false;
  String? errorMessage;
  RuntimeSnapshot runtimeStatus = RuntimeSnapshot.empty;

  late final TextEditingController proxyController;
  late final TextEditingController directController;
  late final TextEditingController blockedController;
  late final TextEditingController searchController;

  List<String> proxyDomains = const [];
  List<String> directDomains = const [];
  List<String> blockedDomains = const [];
  List<ServerProfile> profiles = const [];

  String activeProfileId = '';
  String externalIp = '';
  bool isLoadingExternalIp = false;

  @override
  void initState() {
    super.initState();
    backendRuntime = BackendRuntime(backend);
    proxyController = TextEditingController();
    directController = TextEditingController();
    blockedController = TextEditingController();
    searchController = TextEditingController();
    _bootstrap();
    pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshState(silent: true);
    });
  }

  @override
  void dispose() {
    pollTimer?.cancel();
    unawaited(backendRuntime.dispose());
    proxyController.dispose();
    directController.dispose();
    blockedController.dispose();
    searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      await backendRuntime.ensureRunning();
    } catch (error) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = error.toString();
        });
      }
      return;
    }
    await _refreshState();
  }

  bool get hasActiveProfile =>
      profiles.any((profile) => profile.id == activeProfileId);

  TunnelMode get tunnelMode => tunEnabled ? TunnelMode.vpn : TunnelMode.proxy;

  ServerProfile get activeProfile => profiles.firstWhere(
        (profile) => profile.id == activeProfileId,
        orElse: () => const ServerProfile(
          id: 'none',
          name: 'Profile not selected',
          latencyMs: 0,
          health: ProfileHealth.offline,
          protocol: '-',
        ),
      );

  List<ServerProfile> get filteredProfiles {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return profiles;
    }

    return profiles
        .where(
          (profile) =>
              profile.name.toLowerCase().contains(query) ||
              profile.protocol.toLowerCase().contains(query) ||
              profile.address.toLowerCase().contains(query) ||
              profile.sni.toLowerCase().contains(query) ||
              profile.host.toLowerCase().contains(query) ||
              profile.transport.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWide = MediaQuery.of(context).size.width >= 1100;
    final content = _buildBody(isDesktopWide);
    Widget blurOrb(double size, Color color) {
      return ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 56, sigmaY: 56),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.06, -0.25),
            radius: 1.45,
            colors: [
              AppPalette.homeBgTop,
              AppPalette.homeBgMid,
              AppPalette.homeBgBottom,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                Positioned(
                  top: -34,
                  left: -40,
                  child: blurOrb(
                    280,
                    const Color(0x335A74F5),
                  ),
                ),
                Positioned(
                  top: 200,
                  right: -70,
                  child: blurOrb(
                    340,
                    const Color(0x20495BB3),
                  ),
                ),
                Positioned(
                  bottom: 46,
                  left: MediaQuery.of(context).size.width * 0.28,
                  child: blurOrb(
                    220,
                    const Color(0x22333F88),
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _WorldMapBackdropPainter(),
                    ),
                  ),
                ),
                content,
                if (isBusy)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF090D1C).withValues(alpha: 0.56),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDesktopWide) {
    if (isLoading && profiles.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && profiles.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            elevation: 0,
            color: Colors.white.withValues(alpha: 0.86),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Backend unavailable',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.black.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _refreshState,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return isDesktopWide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 280,
                child: _Sidebar(
                  connection: connection,
                  routingMode: routingMode,
                  dnsMode: dnsMode,
                  selectedPage: selectedPage,
                  onSelect: (page) {
                    setState(() {
                      selectedPage = page;
                    });
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: _buildContent()),
            ],
          )
        : _buildMobileLayout();
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Expanded(child: _buildContent()),
        const SizedBox(height: 12),
        NavigationBar(
          selectedIndex: selectedPage.index,
          onDestinationSelected: (index) {
            setState(() {
              selectedPage = AppPage.values[index];
            });
          },
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.home_outlined), label: 'Home'),
            NavigationDestination(
                icon: Icon(Icons.rule_folder_outlined), label: 'Rules'),
            NavigationDestination(
                icon: Icon(Icons.dns_outlined), label: 'Profiles'),
            NavigationDestination(
                icon: Icon(Icons.tune_outlined), label: 'Settings'),
          ],
        ),
      ],
    );
  }

  Future<void> _refreshState({bool silent = false}) async {
    if (isRefreshing || isBusy) {
      return;
    }

    isRefreshing = true;
    if (!silent) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final snapshot = await backend.getState();
      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
        if (!silent) {
          isLoading = false;
        }
      });
      unawaited(_syncExternalIp());
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (!silent) {
        setState(() {
          isLoading = false;
          errorMessage = error.toString();
        });
      }
    } finally {
      isRefreshing = false;
    }
  }

  Future<void> _saveConfig(AppConfigState config) async {
    setState(() {
      isBusy = true;
      errorMessage = null;
    });

    try {
      final snapshot = await backend.updateState(config);
      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
      });
      unawaited(_syncExternalIp());
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  Future<void> _toggleConnection() async {
    if (connection == ConnectionStateValue.disconnected && !hasActiveProfile) {
      _showMessage('Select or create a profile first.', isError: true);
      return;
    }

    setState(() {
      isBusy = true;
      errorMessage = null;
    });

    try {
      final snapshot = connection == ConnectionStateValue.connected
          ? await backend.disconnect()
          : await backend.connect();
      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
      });
      unawaited(_syncExternalIp());
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          isBusy = false;
        });
      }
    }
  }

  Future<void> _switchTunnelMode(TunnelMode mode) async {
    if (mode == tunnelMode) {
      return;
    }

    if (mode == TunnelMode.vpn) {
      final elevated = await _ensureAdminForTun();
      if (!elevated) {
        return;
      }
      await _saveConfig(
        _currentConfig().copyWith(
          tunEnabled: true,
          systemProxyEnabled: false,
        ),
      );
      return;
    }

    await _saveConfig(
      _currentConfig().copyWith(
        tunEnabled: false,
        systemProxyEnabled: true,
      ),
    );
  }

  Future<bool> _ensureAdminForTun() async {
    final elevated = runtimeStatus.elevated || await backend.getAdminStatus();
    if (elevated) {
      return true;
    }

    try {
      await backend.requestAdmin();
    } catch (error) {
      final message = error.toString().toLowerCase();
      final reconnectExpected = message.contains('socket') ||
          message.contains('connection') ||
          message.contains('connection reset');
      if (!reconnectExpected) {
        if (mounted) {
          _showMessage(error.toString(), isError: true);
        }
        return false;
      }
    }

    if (mounted) {
      _showMessage(
          'Approve the administrator prompt. Waiting for elevated backend...');
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final snapshot = await backend.getState();
        if (snapshot.runtime.elevated) {
          if (mounted) {
            setState(() {
              _applySnapshot(snapshot);
              errorMessage = null;
            });
          }
          return true;
        }
      } catch (_) {
        // Ignore short reconnect gaps while the backend restarts elevated.
      }
    }

    if (mounted) {
      _showMessage('Failed to reconnect to an elevated backend.',
          isError: true);
    }
    return false;
  }

  void _applySnapshot(DashboardSnapshot snapshot) {
    final config = snapshot.config;
    connection = config.connectionState;
    routingMode = config.routingMode;
    dnsMode = config.dnsMode;
    systemProxyEnabled = config.systemProxyEnabled;
    tunEnabled = config.tunEnabled;
    launchAtStartup = config.launchAtStartup;
    proxyDomains = List<String>.from(config.proxyDomains);
    directDomains = List<String>.from(config.directDomains);
    blockedDomains = List<String>.from(config.blockedDomains);
    profiles = List<ServerProfile>.from(config.profiles);
    activeProfileId = config.activeProfileId;
    runtimeStatus = snapshot.runtime;
  }

  Future<void> _syncExternalIp() async {
    if (connection != ConnectionStateValue.connected) {
      if (!mounted) {
        return;
      }
      setState(() {
        externalIp = '';
        isLoadingExternalIp = false;
      });
      return;
    }

    if (isLoadingExternalIp) {
      return;
    }

    setState(() {
      isLoadingExternalIp = true;
    });

    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org?format=json'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode < 400) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final ip = (decoded['ip'] ?? '').toString();
          if (mounted) {
            setState(() {
              externalIp = ip;
            });
          }
        }
      }
    } catch (_) {
      // Keep previous IP if lookup fails.
    } finally {
      if (mounted) {
        setState(() {
          isLoadingExternalIp = false;
        });
      }
    }
  }

  AppConfigState _currentConfig() {
    return AppConfigState(
      activeProfileId: activeProfileId,
      connectionState: connection,
      routingMode: routingMode,
      dnsMode: dnsMode,
      systemProxyEnabled: systemProxyEnabled,
      tunEnabled: tunEnabled,
      launchAtStartup: launchAtStartup,
      proxyDomains: List<String>.from(proxyDomains),
      directDomains: List<String>.from(directDomains),
      blockedDomains: List<String>.from(blockedDomains),
      profiles: List<ServerProfile>.from(profiles),
    );
  }

  Future<void> _showLogsDialog() async {
    final logLines = <String>[
      if (runtimeStatus.binaryPath.isNotEmpty)
        'Binary: ${runtimeStatus.binaryPath}',
      if (runtimeStatus.configPath.isNotEmpty)
        'Config: ${runtimeStatus.configPath}',
      if (runtimeStatus.lastError.isNotEmpty)
        'Last error: ${runtimeStatus.lastError}',
      if (runtimeStatus.lastExit.isNotEmpty)
        'Last exit: ${runtimeStatus.lastExit}',
      if (runtimeStatus.logs.isEmpty) 'No logs captured yet.',
      ...runtimeStatus.logs,
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xray logs'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: SelectableText(logLines.join('\n')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? const Color(0xFF8B3A3A) : null,
        content: Text(message),
      ),
    );
  }

  Widget _buildContent() {
    switch (selectedPage) {
      case AppPage.home:
        return _buildHomeView();
      case AppPage.rules:
        return _buildRulesView();
      case AppPage.profiles:
        return _buildProfilesView();
      case AppPage.settings:
        return _buildSettingsView();
    }
  }

  Widget _buildHomeView() {
    final canConnect = hasActiveProfile;
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxContentWidth =
            constraints.maxWidth >= 1300 ? 980.0 : constraints.maxWidth;
        final horizontalPadding = constraints.maxWidth >= 900 ? 16.0 : 6.0;
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              children: [
                _MainConnectionCard(
                  profileName: hasActiveProfile
                      ? activeProfile.name
                      : 'Select VPN Server',
                  connection: connection,
                  canConnect: canConnect,
                  isBusy: isBusy,
                  onToggleConnection: _toggleConnection,
                  profileItems: profiles,
                  selectedProfileId: hasActiveProfile
                      ? activeProfileId
                      : (profiles.isNotEmpty ? profiles.first.id : null),
                  onProfileChanged: (profileId) async {
                    if (profileId == null) {
                      return;
                    }
                    await _saveConfig(
                        _currentConfig().copyWith(activeProfileId: profileId));
                  },
                  tunnelMode: tunnelMode,
                  onTunnelModeChanged: _switchTunnelMode,
                  externalIp: externalIp,
                  isLoadingExternalIp: isLoadingExternalIp,
                  statusText: runtimeStatus.running
                      ? '${runtimeStatus.mode.toUpperCase()} • ${runtimeStatus.latencyMs > 0 ? '${runtimeStatus.latencyMs} ms' : 'ping n/a'}'
                      : runtimeStatus.lastError.isNotEmpty
                          ? runtimeStatus.lastError
                          : 'Core offline',
                ),
                if (!canConnect) ...[
                  const SizedBox(height: 16),
                  _HintCard(
                    title: 'No profile selected',
                    description:
                        'Open Profiles, import or create a profile, then select it on this screen.',
                    icon: Icons.info_outline_rounded,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRulesView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useThreeColumns = constraints.maxWidth >= 1050;
        final useTwoColumns = constraints.maxWidth >= 700;
        final cards = _rulesCards();

        if (useThreeColumns) {
          return ListView(
            children: [
              const _PageHeader(
                eyebrow: 'Rules',
                title: 'Routing rules',
                description:
                    'Choose routing mode and edit domain lists that go via proxy, direct, or blocked.',
              ),
              const SizedBox(height: 16),
              _RoutingModeCard(
                routingMode: routingMode,
                onModeChanged: (value) =>
                    _saveConfig(_currentConfig().copyWith(routingMode: value)),
              ),
              const SizedBox(height: 16),
              const _RulesSummaryCard(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 16),
                  Expanded(child: cards[2]),
                ],
              ),
            ],
          );
        }

        if (useTwoColumns) {
          return ListView(
            children: [
              const _PageHeader(
                eyebrow: 'Rules',
                title: 'Routing rules',
                description:
                    'Choose routing mode and edit domain lists that go via proxy, direct, or blocked.',
              ),
              const SizedBox(height: 16),
              _RoutingModeCard(
                routingMode: routingMode,
                onModeChanged: (value) =>
                    _saveConfig(_currentConfig().copyWith(routingMode: value)),
              ),
              const SizedBox(height: 16),
              const _RulesSummaryCard(),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.05,
                children: cards,
              ),
            ],
          );
        }

        return ListView.separated(
          itemCount: cards.length + 3,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _PageHeader(
                eyebrow: 'Rules',
                title: 'Routing rules',
                description:
                    'Choose routing mode and edit domain lists that go via proxy, direct, or blocked.',
              );
            }
            if (index == 1) {
              return _RoutingModeCard(
                routingMode: routingMode,
                onModeChanged: (value) =>
                    _saveConfig(_currentConfig().copyWith(routingMode: value)),
              );
            }
            if (index == 2) {
              return const _RulesSummaryCard();
            }
            return cards[index - 3];
          },
        );
      },
    );
  }

  List<Widget> _rulesCards() {
    return [
      _buildDomainCard(
        title: 'Via proxy',
        description: 'Domains that should always go through Xray.',
        domains: proxyDomains,
        controller: proxyController,
        accent: const Color(0xFF0E5E6F),
        placeholder: 'github.com',
        onAdd: () => _addDomain(
          proxyController,
          proxyDomains,
          (items) =>
              _saveConfig(_currentConfig().copyWith(proxyDomains: items)),
        ),
        onRemove: (domain) => _saveConfig(
          _currentConfig().copyWith(
            proxyDomains: proxyDomains.where((item) => item != domain).toList(),
          ),
        ),
      ),
      _buildDomainCard(
        title: 'Direct',
        description: 'Domains that bypass the tunnel.',
        domains: directDomains,
        controller: directController,
        accent: const Color(0xFF6E5D46),
        placeholder: 'bank.ru',
        onAdd: () => _addDomain(
          directController,
          directDomains,
          (items) =>
              _saveConfig(_currentConfig().copyWith(directDomains: items)),
        ),
        onRemove: (domain) => _saveConfig(
          _currentConfig().copyWith(
            directDomains:
                directDomains.where((item) => item != domain).toList(),
          ),
        ),
      ),
      _buildDomainCard(
        title: 'Blocked',
        description: 'Domains that should be dropped completely.',
        domains: blockedDomains,
        controller: blockedController,
        accent: const Color(0xFF8B3A3A),
        placeholder: 'ads.example.com',
        onAdd: () => _addDomain(
          blockedController,
          blockedDomains,
          (items) =>
              _saveConfig(_currentConfig().copyWith(blockedDomains: items)),
        ),
        onRemove: (domain) => _saveConfig(
          _currentConfig().copyWith(
            blockedDomains:
                blockedDomains.where((item) => item != domain).toList(),
          ),
        ),
      ),
    ];
  }

  Widget _buildDomainCard({
    required String title,
    required String description,
    required List<String> domains,
    required TextEditingController controller,
    required Color accent,
    required String placeholder,
    required Future<void> Function() onAdd,
    required Future<void> Function(String) onRemove,
  }) {
    return Card(
      elevation: 0,
      color: AppPalette.card.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(description,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onSubmitted: (_) {
                      onAdd();
                    },
                    decoration: InputDecoration(
                      hintText: placeholder,
                      filled: true,
                      fillColor: const Color(0xFFF7F3EC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: () {
                    onAdd();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                  style: AppUi.primaryButton(accent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F7F2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: domains.isEmpty
                    ? Text(
                        'No entries yet.',
                        style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.5)),
                      )
                    : ListView.separated(
                        itemCount: domains.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final domain = domains[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.public_rounded,
                                    size: 18, color: accent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    domain,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    onRemove(domain);
                                  },
                                  icon:
                                      const Icon(Icons.delete_outline_rounded),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilesView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final list = Card(
          elevation: 0,
          color: AppPalette.card.withValues(alpha: 0.72),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5477DF),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              color: Colors.white, size: 28),
                          Spacer(),
                          Text(
                            'Server List',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Spacer(),
                          SizedBox(width: 28),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        style: AppUi.segmentedHeaderButton(),
                        segments: const [
                          ButtonSegment(
                              value: 0, label: Text('Standard Servers')),
                          ButtonSegment(
                              value: 1, label: Text('Premium Servers')),
                        ],
                        selected: const {0},
                        onSelectionChanged: (_) {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: constraints.maxWidth > 860
                          ? 320
                          : constraints.maxWidth,
                      child: TextField(
                        controller: searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search profiles, SNI or address',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: const Color(0xFFF7F3EC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _importProfileFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded),
                      label: const Text('Import clipboard'),
                      style: AppUi.primaryButton(AppPalette.blueDark),
                    ),
                    OutlinedButton.icon(
                      onPressed: _showProfileImportDialog,
                      icon: const Icon(Icons.add_link_rounded),
                      label: const Text('Manual import'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: filteredProfiles.isEmpty
                      ? const Center(
                          child: _HintCard(
                            title: 'No profiles yet',
                            description:
                                'Import a profile from clipboard or add it manually to start.',
                            icon: Icons.account_tree_outlined,
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredProfiles.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final profile = filteredProfiles[index];
                            final isActive = profile.id == activeProfileId;

                            return Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? const Color(0xFF4A6FD8)
                                    : const Color(0xFF5477DF),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _cityFlag(profile),
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                profile.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.96),
                                                ),
                                              ),
                                            ),
                                            if (isActive)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.16),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    999,
                                                  ),
                                                ),
                                                child: const Text(
                                                  'Active',
                                                  style: TextStyle(
                                                      color: Colors.white),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '${profile.protocol.toUpperCase()} • ${profile.address.isEmpty ? 'no endpoint' : '${profile.address}:${profile.port}'}',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.84,
                                            ),
                                          ),
                                        ),
                                        if (profile.transport.isNotEmpty ||
                                            profile.security.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              '${profile.transport.isEmpty ? 'tcp' : profile.transport} • ${profile.security.isEmpty ? 'none' : profile.security}',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.52,
                                                ),
                                              ),
                                            ),
                                          ),
                                        if (profile.sni.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 4,
                                            ),
                                            child: Text(
                                              'SNI ${profile.sni}',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.52,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  _HealthBadge(health: profile.health),
                                  const SizedBox(width: 12),
                                  IconButton.outlined(
                                    onPressed: () => _removeProfile(profile.id),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton.tonal(
                                    onPressed: () => _saveConfig(
                                      _currentConfig().copyWith(
                                        activeProfileId: profile.id,
                                      ),
                                    ),
                                    child: Text(isActive ? 'Selected' : 'Use'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.2),
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );

        final details = _ProfileDetailsCard(profile: activeProfile);

        if (constraints.maxWidth >= 1160) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: list),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: details),
            ],
          );
        }

        return ListView(
          children: [
            SizedBox(height: 680, child: list),
            const SizedBox(height: 16),
            details,
          ],
        );
      },
    );
  }

  Widget _buildSettingsView() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const _MobileTopBar(
          title: 'Settings',
          trailing: Icons.menu,
          titleAlign: Alignment.centerLeft,
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: AppPalette.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              const _SectionLabel('Settings'),
              _SettingsSimpleTile(
                icon: Icons.palette_outlined,
                title: 'Theme Mode',
                onTap: () => _showMessage('Theme switch will be added next.'),
              ),
              _SettingsSimpleTile(
                icon: Icons.language,
                title: 'Language',
                onTap: () =>
                    _showMessage('Language picker will be added next.'),
              ),
              _SettingsSimpleTile(
                icon: Icons.refresh,
                title: 'Check for Updates',
                onTap: () => _showMessage('No updates available right now.'),
              ),
              const SizedBox(height: 14),
              const _SectionLabel('Connection'),
              _SettingsSwitchTile(
                icon: Icons.shield_rounded,
                title: 'VPN (TUN) Mode',
                subtitle: 'Protect all applications',
                value: tunEnabled,
                onChanged: (value) async {
                  if (value) {
                    final elevated = await _ensureAdminForTun();
                    if (!elevated) {
                      return;
                    }
                  }
                  await _saveConfig(
                    _currentConfig().copyWith(
                      tunEnabled: value,
                      systemProxyEnabled: !value,
                    ),
                  );
                },
              ),
              _SettingsSwitchTile(
                icon: Icons.launch_rounded,
                title: 'Launch at startup',
                subtitle: 'Start with last selected profile',
                value: launchAtStartup,
                onChanged: (value) => _saveConfig(
                  _currentConfig().copyWith(launchAtStartup: value),
                ),
              ),
              _SettingsSimpleTile(
                icon: Icons.terminal_rounded,
                title: 'Open Logs',
                onTap: _showLogsDialog,
              ),
              const SizedBox(height: 14),
              const _SectionLabel('About Us'),
              _SettingsSimpleTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () =>
                    _showMessage('Privacy Policy page is not connected yet.'),
              ),
              _SettingsSimpleTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _showMessage('Terms page is not connected yet.'),
              ),
              _SettingsSimpleTile(
                icon: Icons.info_outline,
                title: 'About',
                onTap: () => _showMessage('Troodi VPN • Flutter + Go + Xray'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addDomain(
    TextEditingController controller,
    List<String> current,
    Future<void> Function(List<String>) apply,
  ) async {
    final value = _normalizeDomain(controller.text);
    if (value.isEmpty || current.contains(value)) {
      return;
    }
    await apply([value, ...current]);
    controller.clear();
  }

  Future<void> _saveProfiles(List<ServerProfile> nextProfiles) async {
    final nextActive =
        nextProfiles.any((profile) => profile.id == activeProfileId)
            ? activeProfileId
            : (nextProfiles.isNotEmpty ? nextProfiles.first.id : '');
    await _saveConfig(
      _currentConfig().copyWith(
        profiles: nextProfiles,
        activeProfileId: nextActive,
      ),
    );
  }

  Future<void> _importProfileFromClipboard() async {
    final clipboard = await Clipboard.getData('text/plain');
    final raw = clipboard?.text?.trim() ?? '';
    if (raw.isEmpty) {
      _showMessage('Clipboard is empty.', isError: true);
      return;
    }
    try {
      final imported = _parseProfilesInput(raw);
      await _saveProfiles([...imported, ...profiles]);
      if (mounted) {
        _showMessage(
          imported.length == 1
              ? 'Profile imported from clipboard.'
              : '${imported.length} profiles imported from clipboard.',
        );
      }
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _showProfileImportDialog() async {
    final imported = await showDialog<List<ServerProfile>>(
      context: context,
      builder: (context) => const _ProfileImportDialog(),
    );
    if (imported == null || imported.isEmpty) {
      return;
    }
    await _saveProfiles([...imported, ...profiles]);
    if (mounted) {
      _showMessage(
        imported.length == 1
            ? 'Profile added.'
            : '${imported.length} profiles added.',
      );
    }
  }

  Future<void> _removeProfile(String profileId) async {
    final nextProfiles =
        profiles.where((profile) => profile.id != profileId).toList();
    await _saveProfiles(nextProfiles);
  }

  String _normalizeDomain(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    final withoutScheme = trimmed.replaceFirst(RegExp(r'^https?://'), '');
    final slashIndex = withoutScheme.indexOf('/');
    return slashIndex >= 0
        ? withoutScheme.substring(0, slashIndex)
        : withoutScheme;
  }

  String _cityFlag(ServerProfile profile) {
    final value = '${profile.name} ${profile.address}'.toLowerCase();
    if (value.contains('us') || value.contains('new york')) {
      return '🇺🇸';
    }
    if (value.contains('de') || value.contains('frankfurt')) {
      return '🇩🇪';
    }
    if (value.contains('fr') ||
        value.contains('paris') ||
        value.contains('bordeaux')) {
      return '🇫🇷';
    }
    if (value.contains('fi') || value.contains('helsinki')) {
      return '🇫🇮';
    }
    if (value.contains('in') || value.contains('delhi')) {
      return '🇮🇳';
    }
    if (value.contains('au') || value.contains('perth')) {
      return '🇦🇺';
    }
    if (value.contains('ru') || value.contains('moscow')) {
      return '🇷🇺';
    }
    return '🌐';
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.connection,
    required this.routingMode,
    required this.dnsMode,
    required this.selectedPage,
    required this.onSelect,
  });

  final ConnectionStateValue connection;
  final RoutingMode routingMode;
  final DnsMode dnsMode;
  final AppPage selectedPage;
  final ValueChanged<AppPage> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      (AppPage.home, 'Home', Icons.home_outlined),
      (AppPage.rules, 'Rules', Icons.rule_folder_outlined),
      (AppPage.profiles, 'Profiles', Icons.dns_outlined),
      (AppPage.settings, 'Settings', Icons.tune_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppPalette.card.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _TroodiLogo(size: 48),
              SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Troodi VPN',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Minimal Xray desktop client',
                      style: TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          for (var index = 0; index < items.length; index++) ...[
            _NavButton(
              label: items[index].$2,
              icon: items[index].$3,
              selected: items[index].$1 == selectedPage,
              onTap: () => onSelect(items[index].$1),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F3EC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Quick status',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                _StatusRow(
                  label: 'Connection',
                  value: connection == ConnectionStateValue.connected
                      ? 'Connected'
                      : 'Disconnected',
                ),
                const SizedBox(height: 10),
                _StatusRow(label: 'Routing', value: routingMode.name),
                const SizedBox(height: 10),
                _StatusRow(label: 'DNS', value: dnsMode.name.toUpperCase()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.eyebrow,
    required this.title,
    required this.description,
  });

  final String eyebrow;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
            color: Color(0xFF6E5D46),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: TextStyle(color: Colors.black.withValues(alpha: 0.64)),
        ),
      ],
    );
  }
}

class _TroodiLogo extends StatelessWidget {
  const _TroodiLogo({this.size = 52});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0E5E6F), Color(0xFF173C4A)],
        ),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_outlined, color: Colors.white, size: size * 0.5),
          Positioned(
            bottom: size * 0.16,
            child: Container(
              width: size * 0.28,
              height: size * 0.06,
              decoration: BoxDecoration(
                color: const Color(0xFFE8D39D),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeInfoSection extends StatelessWidget {
  const _HomeInfoSection({
    required this.profile,
    required this.runtimeStatus,
    required this.routingMode,
    required this.systemProxyEnabled,
    required this.tunEnabled,
  });

  final ServerProfile profile;
  final RuntimeSnapshot runtimeStatus;
  final RoutingMode routingMode;
  final bool systemProxyEnabled;
  final bool tunEnabled;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        label: 'Endpoint',
        value: profile.address.isEmpty
            ? 'Not configured'
            : '${profile.address}:${profile.port}',
        accent: const Color(0xFF173C4A),
      ),
      _MetricCard(
        label: 'SNI',
        value: profile.sni.isEmpty ? 'Not specified' : profile.sni,
        accent: const Color(0xFF6E5D46),
      ),
      _MetricCard(
        label: 'Routing',
        value:
            '${routingMode.name} / ${tunEnabled ? 'TUN' : systemProxyEnabled ? 'Proxy' : 'Manual'}',
        accent: const Color(0xFF2C7A5D),
      ),
    ];

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: cards,
    );
  }
}

class _RulesSummaryCard extends StatelessWidget {
  const _RulesSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.card.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Wrap(
        spacing: 14,
        runSpacing: 14,
        children: [
          _ChipLabel(label: 'Default mode: Global'),
          _ChipLabel(label: 'Whitelist: listed domains via proxy'),
          _ChipLabel(label: 'Blacklist: listed domains direct'),
          _ChipLabel(label: 'Blocked list: always dropped'),
        ],
      ),
    );
  }
}

class _RegionPresetCard extends StatelessWidget {
  const _RegionPresetCard({required this.onApplyRuPreset});

  final VoidCallback onApplyRuPreset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const SizedBox(
            width: 340,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Preset regions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Later this section will pull curated profile packs by region and merge them with your routing rules.',
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: onApplyRuPreset,
            icon: const Icon(Icons.public_rounded),
            label: const Text('Preset RU'),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({required this.profile});

  final ServerProfile profile;

  @override
  Widget build(BuildContext context) {
    final hostPath = [
      if (profile.host.isNotEmpty) profile.host,
      if (profile.path.isNotEmpty) profile.path,
    ];
    final reality = [
      if (profile.realityPublicKey.isNotEmpty) 'pk ${profile.realityPublicKey}',
      if (profile.realityShortId.isNotEmpty) 'sid ${profile.realityShortId}',
      if (profile.spiderX.isNotEmpty) 'spx ${profile.spiderX}',
    ];

    return Card(
      elevation: 0,
      color: AppPalette.card.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Profile details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _StatusRow(label: 'Name', value: profile.name),
            const SizedBox(height: 10),
            _StatusRow(
                label: 'Protocol', value: profile.protocol.toUpperCase()),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Address',
              value: profile.address.isEmpty
                  ? 'Not specified'
                  : '${profile.address}:${profile.port}',
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'SNI',
              value: profile.sni.isEmpty ? 'Not specified' : profile.sni,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Security',
              value: profile.security.isEmpty ? 'Auto' : profile.security,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Transport',
              value: profile.transport.isEmpty ? 'tcp' : profile.transport,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'ALPN',
              value: profile.alpn.isEmpty ? 'Not specified' : profile.alpn,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Fingerprint',
              value: profile.fingerprint.isEmpty
                  ? 'Not specified'
                  : profile.fingerprint,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Flow',
              value: profile.flow.isEmpty ? 'Not specified' : profile.flow,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Host / path',
              value: hostPath.isEmpty ? 'Not specified' : hostPath.join('  '),
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Reality',
              value: reality.isEmpty ? 'Not specified' : reality.join('  '),
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Credential',
              value: profile.userId.isNotEmpty
                  ? profile.userId
                  : profile.password.isNotEmpty
                      ? profile.password
                      : 'Not specified',
            ),
            if (profile.rawLink.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F3EC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(profile.rawLink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MobileTopBar extends StatelessWidget {
  const _MobileTopBar({
    required this.title,
    this.leading,
    this.trailing,
    this.trailingIsCrown = false,
    this.titleAlign = Alignment.center,
  });

  final String title;
  final IconData? leading;
  final IconData? trailing;
  final bool trailingIsCrown;
  final Alignment titleAlign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            _CircleGhostIcon(icon: leading, visible: leading != null),
            Expanded(
              child: Align(
                alignment: titleAlign,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.homeText,
                  ),
                ),
              ),
            ),
            trailingIsCrown
                ? const _CrownBadge()
                : _CircleGhostIcon(icon: trailing, visible: trailing != null),
          ],
        ),
      ),
    );
  }
}

class _CircleGhostIcon extends StatelessWidget {
  const _CircleGhostIcon({required this.icon, required this.visible});

  final IconData? icon;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: visible
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                boxShadow: [AppShadows.darkCard],
              ),
              child: Icon(
                icon,
                color: AppPalette.homeText.withValues(alpha: 0.9),
                size: 22,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _CrownBadge extends StatelessWidget {
  const _CrownBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        shape: BoxShape.circle,
        boxShadow: [AppShadows.darkCard],
      ),
      child: Icon(
        Icons.workspace_premium_rounded,
        color: AppPalette.homeText.withValues(alpha: 0.84),
        size: 22,
      ),
    );
  }
}

class _MainConnectionCard extends StatelessWidget {
  const _MainConnectionCard({
    required this.profileName,
    required this.connection,
    required this.canConnect,
    required this.isBusy,
    required this.onToggleConnection,
    required this.profileItems,
    required this.selectedProfileId,
    required this.onProfileChanged,
    required this.tunnelMode,
    required this.onTunnelModeChanged,
    required this.externalIp,
    required this.isLoadingExternalIp,
    required this.statusText,
  });

  final String profileName;
  final ConnectionStateValue connection;
  final bool canConnect;
  final bool isBusy;
  final Future<void> Function() onToggleConnection;
  final List<ServerProfile> profileItems;
  final String? selectedProfileId;
  final ValueChanged<String?> onProfileChanged;
  final TunnelMode tunnelMode;
  final ValueChanged<TunnelMode> onTunnelModeChanged;
  final String externalIp;
  final bool isLoadingExternalIp;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final connected = connection == ConnectionStateValue.connected;
    final statusLabel = connected ? 'CONNECTED' : 'DISCONNECTED';
    final statusColor =
        connected ? AppPalette.homeAccent : const Color(0xFF8D95B2);
    final flag = _guessFlag(profileName);
    final isCompact = MediaQuery.of(context).size.width < 760;

    final topCardWidth = isCompact ? double.infinity : 1040.0;
    final bottomCardWidth = isCompact ? double.infinity : 880.0;

    return Container(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          const _MobileTopBar(
            title: 'Troodi VPN',
            leading: Icons.menu,
            trailing: Icons.account_circle_outlined,
          )
              .animate()
              .fadeIn(duration: 320.ms)
              .slideY(begin: -0.08, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: topCardWidth),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.white.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.14)),
                  boxShadow: [AppShadows.darkCard],
                ),
                child: Column(
                  children: [
                    Text(
                      'Network Activity',
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.78),
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _TrafficStat(
                            label: 'Download',
                            value: connected ? '0 B/s' : '0 B/s',
                            icon: Icons.arrow_downward_rounded,
                            iconColor: const Color(0xFF71C6FF),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 60,
                          color: Colors.white.withValues(alpha: 0.14),
                        ),
                        Expanded(
                          child: _TrafficStat(
                            label: 'Upload',
                            value: connected ? '0 B/s' : '0 B/s',
                            icon: Icons.arrow_upward_rounded,
                            iconColor: const Color(0xFFA9A8FF),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: AppPalette.homeTextMuted,
                        fontSize: 16,
                      ),
                    ),
                    if (externalIp.isNotEmpty || isLoadingExternalIp) ...[
                      const SizedBox(height: 6),
                      Text(
                        isLoadingExternalIp
                            ? 'IP checking...'
                            : 'Public IP: $externalIp',
                        style: TextStyle(
                          color: AppPalette.homeText.withValues(alpha: 0.72),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
              .animate(delay: 90.ms)
              .fadeIn(duration: 360.ms)
              .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1)),
          const SizedBox(height: 22),
          Center(
            child: Text(
              statusLabel,
              style: TextStyle(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
                fontSize: isCompact ? 26 : 32,
                color: AppPalette.homeTextMuted.withValues(alpha: 0.88),
              ),
            ),
          ).animate(delay: 150.ms).fadeIn(duration: 240.ms),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: isCompact ? 136 : 146,
              height: isCompact ? 136 : 146,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.9),
                    const Color(0xFFD2D9F0).withValues(alpha: 0.86),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                boxShadow: [
                  AppShadows.glow(statusColor),
                ],
              ),
              child: Center(
                child: IconButton(
                  onPressed: canConnect && !isBusy ? onToggleConnection : null,
                  iconSize: isCompact ? 46 : 52,
                  style: AppUi.powerButton(statusColor),
                  icon: const Icon(Icons.power_settings_new_rounded),
                ),
              ),
            ),
          )
              .animate(delay: 160.ms)
              .fadeIn(duration: 280.ms)
              .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
          const SizedBox(height: 22),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bottomCardWidth),
              child: _ServerSelectCard(
                selectedFlag: flag,
                selectedName:
                    profileItems.isEmpty ? 'No servers yet' : profileName,
                selectedProfileId: selectedProfileId,
                profileItems: profileItems,
                onProfileChanged: onProfileChanged,
              ),
            ),
          )
              .animate(delay: 340.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bottomCardWidth),
              child: _TunnelModeToggle(
                value: tunnelMode,
                onChanged: onTunnelModeChanged,
              ),
            ),
          ).animate(delay: 400.ms).fadeIn(duration: 300.ms),
          const SizedBox(height: 10),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bottomCardWidth),
              child: Text(
                tunnelMode == TunnelMode.vpn
                    ? 'VPN: protects all applications.'
                    : 'Proxy: for selected apps only.',
                style: TextStyle(
                  color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
                  fontSize: 15,
                ),
              ),
            ),
          ).animate(delay: 460.ms).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }

  String _guessFlag(String value) {
    final v = value.toLowerCase();
    if (v.contains('usa') || v.contains('us') || v.contains('new york')) {
      return '🇺🇸';
    }
    if (v.contains('germany') || v.contains('de') || v.contains('frankfurt')) {
      return '🇩🇪';
    }
    if (v.contains('france') || v.contains('paris') || v.contains('bordeaux')) {
      return '🇫🇷';
    }
    if (v.contains('finland') || v.contains('helsinki')) {
      return '🇫🇮';
    }
    if (v.contains('india') || v.contains('delhi')) {
      return '🇮🇳';
    }
    if (v.contains('australia') || v.contains('perth')) {
      return '🇦🇺';
    }
    if (v.contains('russia') || v.contains('ru') || v.contains('moscow')) {
      return '🇷🇺';
    }
    return '🌐';
  }
}

class _ServerSelectCard extends StatelessWidget {
  const _ServerSelectCard({
    required this.selectedFlag,
    required this.selectedName,
    required this.selectedProfileId,
    required this.profileItems,
    required this.onProfileChanged,
  });

  final String selectedFlag;
  final String selectedName;
  final String? selectedProfileId;
  final List<ServerProfile> profileItems;
  final ValueChanged<String?> onProfileChanged;

  Future<void> _openServerPicker(BuildContext context) async {
    if (profileItems.isEmpty) {
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10162B).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(24),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  boxShadow: [AppShadows.darkCard],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            color: AppPalette.homeAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Select VPN Server',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppPalette.homeText.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
                        itemCount: profileItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final profile = profileItems[index];
                          final isSelected = profile.id == selectedProfileId;
                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.of(context).pop(profile.id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppPalette.homeAccent,
                                          AppPalette.homeAccentStrong,
                                        ],
                                      )
                                    : null,
                                color: isSelected
                                    ? null
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.26)
                                      : Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _guessFlagFromName(profile.name),
                                    style: const TextStyle(fontSize: 26),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppPalette.homeText
                                                .withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  else
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppPalette.homeTextMuted
                                          .withValues(alpha: 0.84),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) {
      onProfileChanged(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final disabled = profileItems.isEmpty;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: disabled ? null : () => _openServerPicker(context),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
            ),
            boxShadow: [AppShadows.darkCard],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppPalette.homeAccent.withValues(alpha: 0.22),
                ),
                child: Center(
                  child: Text(
                    selectedFlag,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selectedName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: disabled
                        ? AppPalette.homeTextMuted.withValues(alpha: 0.68)
                        : AppPalette.homeText,
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppPalette.homeTextMuted.withValues(alpha: 0.74),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: AppPalette.homeText.withValues(alpha: 0.88),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _guessFlagFromName(String value) {
    final v = value.toLowerCase();
    if (v.contains('usa') || v.contains('us') || v.contains('new york')) {
      return '🇺🇸';
    }
    if (v.contains('germany') || v.contains('de') || v.contains('frankfurt')) {
      return '🇩🇪';
    }
    if (v.contains('france') || v.contains('paris') || v.contains('bordeaux')) {
      return '🇫🇷';
    }
    if (v.contains('finland') || v.contains('helsinki')) {
      return '🇫🇮';
    }
    if (v.contains('india') || v.contains('delhi')) {
      return '🇮🇳';
    }
    if (v.contains('australia') || v.contains('perth')) {
      return '🇦🇺';
    }
    if (v.contains('russia') || v.contains('ru') || v.contains('moscow')) {
      return '🇷🇺';
    }
    return '🌐';
  }
}

class _TunnelModeToggle extends StatelessWidget {
  const _TunnelModeToggle({
    required this.value,
    required this.onChanged,
  });

  final TunnelMode value;
  final ValueChanged<TunnelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isVpn = value == TunnelMode.vpn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppPalette.homeAccent, AppPalette.homeAccentStrong],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppPalette.homeAccentStrong.withValues(alpha: 0.36),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isVpn ? Icons.shield_rounded : Icons.web_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  isVpn ? 'VPN' : 'Proxy',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [AppShadows.darkCard],
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeSegment(
                  label: 'VPN',
                  icon: Icons.shield_outlined,
                  selected: isVpn,
                  onTap: () => onChanged(TunnelMode.vpn),
                ),
              ),
              Container(
                width: 1,
                color: Colors.white.withValues(alpha: 0.09),
              ),
              Expanded(
                child: _ModeSegment(
                  label: 'Proxy',
                  icon: Icons.web_asset_rounded,
                  selected: !isVpn,
                  onTap: () => onChanged(TunnelMode.proxy),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeSegment extends StatelessWidget {
  const _ModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? AppPalette.homeText.withValues(alpha: 0.9)
                    : AppPalette.homeTextMuted.withValues(alpha: 0.86),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: selected
                      ? AppPalette.homeText.withValues(alpha: 0.9)
                      : AppPalette.homeTextMuted.withValues(alpha: 0.86),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutingModeCard extends StatelessWidget {
  const _RoutingModeCard({
    required this.routingMode,
    required this.onModeChanged,
  });

  final RoutingMode routingMode;
  final ValueChanged<RoutingMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppPalette.card.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Routing mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Default for new users: Global. Switch to Whitelist or Blacklist only when needed.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.62)),
            ),
            const SizedBox(height: 12),
            SegmentedButton<RoutingMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: RoutingMode.global, label: Text('Global')),
                ButtonSegment(
                  value: RoutingMode.whitelist,
                  label: Text('Whitelist'),
                ),
                ButtonSegment(
                  value: RoutingMode.blacklist,
                  label: Text('Blacklist'),
                ),
              ],
              selected: <RoutingMode>{routingMode},
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrafficStat extends StatelessWidget {
  const _TrafficStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: AppPalette.homeText.withValues(alpha: 0.82),
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: AppPalette.homeText.withValues(alpha: 0.95),
                fontSize: 28,
                height: 1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [AppShadows.darkCard],
      ),
      child: Row(
        children: [
          Icon(icon, color: AppPalette.homeAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppPalette.homeText.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: AppPalette.homeTextMuted.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldMapBackdropPainter extends CustomPainter {
  const _WorldMapBackdropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final wave = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final glow = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    Path ribbon(double y1, double c1, double c2, double y2) {
      return Path()
        ..moveTo(0, size.height * y1)
        ..quadraticBezierTo(
          size.width * 0.24,
          size.height * c1,
          size.width * 0.48,
          size.height * c2,
        )
        ..quadraticBezierTo(
          size.width * 0.74,
          size.height * y2,
          size.width,
          size.height * ((y1 + y2) / 2),
        );
    }

    final p1 = ribbon(0.19, 0.34, 0.12, 0.23);
    final p2 = ribbon(0.47, 0.42, 0.67, 0.55);
    final p3 = ribbon(0.74, 0.68, 0.88, 0.81);

    canvas.drawPath(p1, glow);
    canvas.drawPath(p2, glow);
    canvas.drawPath(p3, glow);
    canvas.drawPath(p1, wave);
    canvas.drawPath(p2, wave);
    canvas.drawPath(p3, wave);

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    final midY = size.height * 0.58;
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppPalette.inputFill,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.insights_rounded, color: accent, size: 18),
          ),
          const SizedBox(height: 14),
          Text(label,
              style: TextStyle(color: Colors.black.withValues(alpha: 0.55))),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppPalette.inputFill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppPalette.card.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
              const SizedBox(height: 18),
            ] else
              const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class _SettingsMenuTile extends StatelessWidget {
  const _SettingsMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading:
          Icon(icon, color: Colors.black.withValues(alpha: 0.45), size: 30),
      title: Text(title, style: const TextStyle(fontSize: 20)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.black.withValues(alpha: 0.48)),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: const Color(0xFF4B72DF).withValues(alpha: 0.85),
      ),
      onTap: onTap,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppPalette.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _SettingsSimpleTile extends StatelessWidget {
  const _SettingsSimpleTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minVerticalPadding: 14,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: AppPalette.textMuted, size: 30),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          color: AppPalette.text,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Icon(icon, color: AppPalette.textMuted, size: 30),
      title: Text(title, style: const TextStyle(fontSize: 20)),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.black.withValues(alpha: 0.42)),
      ),
      trailing: Switch(value: value, onChanged: onChanged),
      onTap: () => onChanged(!value),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF173C4A) : const Color(0x00FFFFFF),
          border: Border.all(
            color: selected
                ? const Color(0xFF173C4A)
                : Colors.black.withValues(alpha: 0.06),
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.white : Colors.black87),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: selected ? Colors.white70 : Colors.black45),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.55)))),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({required this.health});

  final ProfileHealth health;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    switch (health) {
      case ProfileHealth.healthy:
        color = const Color(0xFF2C7A5D);
        label = 'Healthy';
      case ProfileHealth.testing:
        color = const Color(0xFF9A6A22);
        label = 'Testing';
      case ProfileHealth.offline:
        color = const Color(0xFF8B3A3A);
        label = 'Offline';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
          style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ImportSectionCard extends StatelessWidget {
  const _ImportSectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3EC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

enum _ProfileImportMode { link, manual }

class _ProfileImportDialog extends StatefulWidget {
  const _ProfileImportDialog();

  @override
  State<_ProfileImportDialog> createState() => _ProfileImportDialogState();
}

class _ProfileImportDialogState extends State<_ProfileImportDialog> {
  _ProfileImportMode mode = _ProfileImportMode.link;
  String protocol = 'vless';
  String transport = 'tcp';
  String security = 'tls';
  String? errorText;

  final linkController = TextEditingController();
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final portController = TextEditingController(text: '443');
  final sniController = TextEditingController();
  final alpnController = TextEditingController(text: 'h2,http/1.1');
  final fingerprintController = TextEditingController(text: 'chrome');
  final flowController = TextEditingController();
  final hostController = TextEditingController();
  final pathController = TextEditingController();
  final realityPublicKeyController = TextEditingController();
  final realityShortIdController = TextEditingController();
  final spiderXController = TextEditingController(text: '/');
  final userIdController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void dispose() {
    for (final controller in [
      linkController,
      nameController,
      addressController,
      portController,
      sniController,
      alpnController,
      fingerprintController,
      flowController,
      hostController,
      pathController,
      realityPublicKeyController,
      realityShortIdController,
      spiderXController,
      userIdController,
      passwordController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import profile'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_ProfileImportMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: _ProfileImportMode.link, label: Text('Link')),
                  ButtonSegment(
                      value: _ProfileImportMode.manual, label: Text('Manual')),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    mode = selection.first;
                    errorText = null;
                  });
                },
              ),
              const SizedBox(height: 18),
              if (mode == _ProfileImportMode.link)
                TextField(
                  controller: linkController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: _dialogDecoration(
                    'Paste one or several links: vless://..., trojan://..., vmess://...',
                  ).copyWith(
                    helperText:
                        'You can paste multiple links separated by new lines.',
                  ),
                )
              else
                Column(
                  children: [
                    _ImportSectionCard(
                      title: 'Endpoint',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              initialValue: protocol,
                              decoration: _dialogDecoration('Protocol'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'vless', child: Text('VLESS')),
                                DropdownMenuItem(
                                    value: 'trojan', child: Text('Trojan')),
                                DropdownMenuItem(
                                    value: 'vmess', child: Text('VMess')),
                                DropdownMenuItem(
                                    value: 'shadowsocks',
                                    child: Text('Shadowsocks')),
                              ],
                              onChanged: (value) => setState(() {
                                protocol = value ?? 'vless';
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              controller: nameController,
                              decoration: _dialogDecoration('Profile name'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: addressController,
                              decoration: _dialogDecoration('Address / host'),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: portController,
                              keyboardType: TextInputType.number,
                              decoration: _dialogDecoration('Port'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ImportSectionCard(
                      title: 'Transport and TLS',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              initialValue: transport,
                              decoration: _dialogDecoration('Transport'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'tcp', child: Text('TCP')),
                                DropdownMenuItem(
                                    value: 'ws', child: Text('WebSocket')),
                                DropdownMenuItem(
                                    value: 'grpc', child: Text('gRPC')),
                                DropdownMenuItem(
                                    value: 'httpupgrade',
                                    child: Text('HTTPUpgrade')),
                              ],
                              onChanged: (value) => setState(() {
                                transport = value ?? 'tcp';
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: DropdownButtonFormField<String>(
                              initialValue: security,
                              decoration: _dialogDecoration('Security'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'tls', child: Text('TLS')),
                                DropdownMenuItem(
                                    value: 'reality', child: Text('Reality')),
                                DropdownMenuItem(
                                    value: 'none', child: Text('None')),
                              ],
                              onChanged: (value) => setState(() {
                                security = value ?? 'tls';
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: sniController,
                              decoration: _dialogDecoration('SNI'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: alpnController,
                              decoration: _dialogDecoration('ALPN'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: fingerprintController,
                              decoration:
                                  _dialogDecoration('Fingerprint / uTLS'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: flowController,
                              decoration: _dialogDecoration('Flow'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ImportSectionCard(
                      title: 'Transport details',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: hostController,
                              decoration: _dialogDecoration('Host / authority'),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: pathController,
                              decoration: _dialogDecoration('Path / service'),
                            ),
                          ),
                          SizedBox(
                            width: 260,
                            child: TextField(
                              controller: realityPublicKeyController,
                              decoration:
                                  _dialogDecoration('Reality public key'),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: realityShortIdController,
                              decoration: _dialogDecoration('Reality short ID'),
                            ),
                          ),
                          SizedBox(
                            width: 180,
                            child: TextField(
                              controller: spiderXController,
                              decoration: _dialogDecoration('Reality spiderX'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ImportSectionCard(
                      title: 'Credentials',
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: 280,
                            child: TextField(
                              controller: userIdController,
                              decoration: _dialogDecoration('UUID / user'),
                            ),
                          ),
                          SizedBox(
                            width: 240,
                            child: TextField(
                              controller: passwordController,
                              decoration: _dialogDecoration('Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(errorText!,
                    style: const TextStyle(color: Color(0xFF8B3A3A))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }

  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF7F3EC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
    );
  }

  void _submit() {
    try {
      final profiles = mode == _ProfileImportMode.link
          ? _parseProfilesInput(linkController.text.trim())
          : [_manualProfile()];
      Navigator.of(context).pop(profiles);
    } catch (error) {
      setState(() {
        errorText = error.toString();
      });
    }
  }

  ServerProfile _manualProfile() {
    final name = nameController.text.trim();
    final address = addressController.text.trim();
    final port = int.tryParse(portController.text.trim()) ?? 0;
    if (name.isEmpty || address.isEmpty || port <= 0) {
      throw Exception('Manual profile requires name, address and valid port.');
    }
    return ServerProfile(
      id: _profileId(name),
      name: name,
      latencyMs: 0,
      health: ProfileHealth.testing,
      protocol: protocol,
      address: address,
      port: port,
      sni: sniController.text.trim(),
      security: security,
      transport: transport,
      alpn: alpnController.text.trim(),
      fingerprint: fingerprintController.text.trim(),
      flow: flowController.text.trim(),
      host: hostController.text.trim(),
      path: pathController.text.trim(),
      realityPublicKey: realityPublicKeyController.text.trim(),
      realityShortId: realityShortIdController.text.trim(),
      spiderX: spiderXController.text.trim(),
      userId: userIdController.text.trim(),
      password: passwordController.text.trim(),
    );
  }
}

List<ServerProfile> _parseProfilesInput(String input) {
  final normalized = input.trim();
  if (normalized.isEmpty) {
    throw Exception('Profile input is empty.');
  }

  final chunks = normalized
      .split(RegExp(r'[\r\n]+'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  if (chunks.length <= 1) {
    return [_parseProfileInput(normalized)];
  }

  return chunks.map(_parseProfileInput).toList();
}

ServerProfile _parseProfileInput(String input) {
  final raw = input.trim();
  if (raw.isEmpty) {
    throw Exception('Profile input is empty.');
  }

  if (raw.startsWith('vmess://')) {
    final payload = raw.substring('vmess://'.length);
    final normalized = base64.normalize(payload);
    final decoded = utf8.decode(base64Decode(normalized));
    final json = jsonDecode(decoded) as Map<String, dynamic>;
    return ServerProfile(
      id: _profileId(json['ps']?.toString() ?? 'vmess-profile'),
      name: json['ps']?.toString() ?? 'VMess profile',
      latencyMs: 0,
      health: ProfileHealth.testing,
      protocol: 'vmess',
      address: json['add']?.toString() ?? '',
      port: int.tryParse(json['port']?.toString() ?? '') ?? 0,
      sni: json['sni']?.toString() ?? json['host']?.toString() ?? '',
      security: json['tls']?.toString() ?? json['scy']?.toString() ?? '',
      transport: json['net']?.toString() ?? 'tcp',
      alpn: json['alpn']?.toString() ?? '',
      fingerprint: json['fp']?.toString() ?? '',
      flow: json['flow']?.toString() ?? '',
      host: json['host']?.toString() ?? '',
      path: json['path']?.toString() ?? '',
      realityPublicKey: json['pbk']?.toString() ?? '',
      realityShortId: json['sid']?.toString() ?? '',
      spiderX: json['spx']?.toString() ?? '',
      userId: json['id']?.toString() ?? '',
      rawLink: raw,
    );
  }

  final uri = Uri.parse(raw);
  final scheme = uri.scheme.toLowerCase();
  if (scheme.isEmpty) {
    throw Exception('Unsupported profile format.');
  }
  final userInfo = uri.userInfo.split(':');
  final credential = userInfo.isNotEmpty ? userInfo.first : '';
  final name = uri.fragment.isNotEmpty
      ? Uri.decodeComponent(uri.fragment)
      : (uri.host.isNotEmpty ? uri.host : '$scheme-profile');

  return ServerProfile(
    id: _profileId(name),
    name: name,
    latencyMs: 0,
    health: ProfileHealth.testing,
    protocol: scheme,
    address: uri.host,
    port: uri.port,
    sni: uri.queryParameters['sni'] ??
        uri.queryParameters['peer'] ??
        uri.queryParameters['host'] ??
        '',
    security: uri.queryParameters['security'] ?? '',
    transport: uri.queryParameters['type'] ??
        uri.queryParameters['transport'] ??
        'tcp',
    alpn: uri.queryParameters['alpn'] ?? '',
    fingerprint:
        uri.queryParameters['fp'] ?? uri.queryParameters['fingerprint'] ?? '',
    flow: uri.queryParameters['flow'] ?? '',
    host: uri.queryParameters['host'] ?? uri.queryParameters['authority'] ?? '',
    path:
        uri.queryParameters['path'] ?? uri.queryParameters['serviceName'] ?? '',
    realityPublicKey:
        uri.queryParameters['pbk'] ?? uri.queryParameters['publicKey'] ?? '',
    realityShortId:
        uri.queryParameters['sid'] ?? uri.queryParameters['shortId'] ?? '',
    spiderX: uri.queryParameters['spx'] ?? '',
    userId: scheme == 'trojan' ? '' : credential,
    password: scheme == 'trojan' ? credential : '',
    rawLink: raw,
  );
}

String _profileId(String seed) {
  final normalized = seed
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final suffix = DateTime.now().millisecondsSinceEpoch.toString();
  return normalized.isEmpty ? suffix : '$normalized-$suffix';
}
