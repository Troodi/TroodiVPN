import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const XrayDesktopApp());
}

class XrayDesktopApp extends StatelessWidget {
  const XrayDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0E5E6F);

    return MaterialApp(
      title: 'Xray Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F0E8),
        fontFamily: 'Segoe UI',
      ),
      home: const DashboardScreen(),
    );
  }
}

enum ConnectionStateValue { connected, disconnected }

enum RoutingMode { global, whitelist, blacklist }

enum DnsMode { auto, proxy, direct }

enum ProfileHealth { healthy, testing, offline }

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.latencyMs,
    required this.health,
    required this.protocol,
  });

  final String id;
  final String name;
  final int latencyMs;
  final ProfileHealth health;
  final String protocol;
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
    required this.logs,
  });

  static const empty = RuntimeSnapshot(
    running: false,
    pid: 0,
    binaryPath: '',
    configPath: '',
    lastError: '',
    lastExit: '',
    logs: <String>[],
  );

  final bool running;
  final int pid;
  final String binaryPath;
  final String configPath;
  final String lastError;
  final String lastExit;
  final List<String> logs;

  factory RuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return RuntimeSnapshot(
      running: json['running'] as bool? ?? false,
      pid: json['pid'] as int? ?? 0,
      binaryPath: json['binaryPath'] as String? ?? '',
      configPath: json['configPath'] as String? ?? '',
      lastError: json['lastError'] as String? ?? '',
      lastExit: json['lastExit'] as String? ?? '',
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

ServerProfile _serverProfileFromJson(Map<String, dynamic> json) {
  return ServerProfile(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'Unnamed profile',
    latencyMs: json['latencyMs'] as int? ?? 0,
    health: _healthFromString(json['health'] as String? ?? 'offline'),
    protocol: json['protocol'] as String? ?? 'unknown',
  );
}

Map<String, dynamic> _serverProfileToJson(ServerProfile profile) {
  return {
    'id': profile.id,
    'name': profile.name,
    'latencyMs': profile.latencyMs,
    'health': profile.health.name,
    'protocol': profile.protocol,
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

  ConnectionStateValue connection = ConnectionStateValue.disconnected;
  RoutingMode routingMode = RoutingMode.blacklist;
  DnsMode dnsMode = DnsMode.auto;
  bool systemProxyEnabled = true;
  bool tunEnabled = false;
  bool launchAtStartup = true;
  int selectedNavigationIndex = 0;
  int selectedTabIndex = 0;
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

  @override
  void initState() {
    super.initState();
    proxyController = TextEditingController();
    directController = TextEditingController();
    blockedController = TextEditingController();
    searchController = TextEditingController();
    _refreshState();
  }

  @override
  void dispose() {
    proxyController.dispose();
    directController.dispose();
    blockedController.dispose();
    searchController.dispose();
    super.dispose();
  }

  ServerProfile get activeProfile => profiles.firstWhere(
        (profile) => profile.id == activeProfileId,
        orElse: () => const ServerProfile(
          id: 'offline',
          name: 'No profile loaded',
          latencyMs: 0,
          health: ProfileHealth.offline,
          protocol: 'Unavailable',
        ),
      );

  List<ServerProfile> get filteredProfiles {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return profiles;
    }

    return profiles
        .where((profile) => profile.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopWide = MediaQuery.of(context).size.width >= 1100;
    final content = _buildBody(isDesktopWide);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF3F0E8),
              Color(0xFFE1EAD8),
              Color(0xFFD9E7E6),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Stack(
              children: [
                content,
                if (isBusy)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.55),
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
                  selectedIndex: selectedNavigationIndex,
                  onSelect: (index) {
                    setState(() {
                      selectedNavigationIndex = index;
                      selectedTabIndex = index == 0 ? 0 : index - 1;
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
          selectedIndex: selectedNavigationIndex,
          onDestinationSelected: (index) {
            setState(() {
              selectedNavigationIndex = index;
              selectedTabIndex = index == 0 ? 0 : index - 1;
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

  Future<void> _refreshState() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final snapshot = await backend.getState();
      if (!mounted) {
        return;
      }

      setState(() {
        _applySnapshot(snapshot);
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
        errorMessage = error.toString();
      });
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HeroCard(
          profile: activeProfile,
          connection: connection,
          routingMode: routingMode,
          proxyCount: proxyDomains.length,
          directCount: directDomains.length,
          runtimeRunning: runtimeStatus.running,
          runtimeInfo: runtimeStatus.running
              ? 'Xray pid ${runtimeStatus.pid}'
              : runtimeStatus.lastError.isNotEmpty
                  ? runtimeStatus.lastError
                  : 'Core offline',
          onToggleConnection: _toggleConnection,
          onModeChanged: (value) async {
            await _saveConfig(_currentConfig().copyWith(routingMode: value));
          },
        ),
        const SizedBox(height: 20),
        Expanded(
          child: IndexedStack(
            index: selectedTabIndex,
            children: [
              _buildRulesView(),
              _buildProfilesView(),
              _buildSettingsView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRulesView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useThreeColumns = constraints.maxWidth >= 1050;
        final useTwoColumns = constraints.maxWidth >= 700;

        if (useThreeColumns) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildDomainCard(
                  title: 'Via proxy',
                  description: 'Domains that should always go through Xray.',
                  domains: proxyDomains,
                  controller: proxyController,
                  accent: const Color(0xFF0E5E6F),
                  placeholder: 'github.com',
                  onAdd: () => _addDomain(
                    proxyController,
                    proxyDomains,
                    (items) => _saveConfig(
                      _currentConfig().copyWith(proxyDomains: items),
                    ),
                  ),
                  onRemove: (domain) => _saveConfig(
                    _currentConfig().copyWith(
                      proxyDomains:
                          proxyDomains.where((item) => item != domain).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDomainCard(
                  title: 'Direct',
                  description: 'Domains that bypass the tunnel.',
                  domains: directDomains,
                  controller: directController,
                  accent: const Color(0xFF6E5D46),
                  placeholder: 'bank.ru',
                  onAdd: () => _addDomain(
                    directController,
                    directDomains,
                    (items) => _saveConfig(
                      _currentConfig().copyWith(directDomains: items),
                    ),
                  ),
                  onRemove: (domain) => _saveConfig(
                    _currentConfig().copyWith(
                      directDomains: directDomains
                          .where((item) => item != domain)
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDomainCard(
                  title: 'Blocked',
                  description: 'Domains that should be dropped completely.',
                  domains: blockedDomains,
                  controller: blockedController,
                  accent: const Color(0xFF8B3A3A),
                  placeholder: 'ads.example.com',
                  onAdd: () => _addDomain(
                    blockedController,
                    blockedDomains,
                    (items) => _saveConfig(
                      _currentConfig().copyWith(blockedDomains: items),
                    ),
                  ),
                  onRemove: (domain) => _saveConfig(
                    _currentConfig().copyWith(
                      blockedDomains: blockedDomains
                          .where((item) => item != domain)
                          .toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        final cards = _rulesCards();
        if (useTwoColumns) {
          return GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.05,
            children: cards,
          );
        }

        return ListView.separated(
          itemCount: cards.length,
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) => cards[index],
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
      color: Colors.white.withValues(alpha: 0.82),
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
                  style: FilledButton.styleFrom(backgroundColor: accent),
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
    return Card(
      elevation: 0,
      color: Colors.white.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Server profiles',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Import subscriptions and choose the active node with minimal UI noise.',
              style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search profiles',
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
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.add_link_rounded),
                  label: const Text('Import subscription'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: filteredProfiles.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final profile = filteredProfiles[index];
                  final isActive = profile.id == activeProfileId;

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F7F2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      profile.name,
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFD4E7E1),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: const Text('Active'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${profile.protocol} • ${profile.latencyMs} ms',
                                style: TextStyle(
                                    color:
                                        Colors.black.withValues(alpha: 0.58)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        _HealthBadge(health: profile.health),
                        const SizedBox(width: 12),
                        FilledButton.tonal(
                          onPressed: () => _saveConfig(
                            _currentConfig().copyWith(
                              activeProfileId: profile.id,
                            ),
                          ),
                          child: Text(isActive ? 'Selected' : 'Use'),
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
  }

  Widget _buildSettingsView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final singleColumn = constraints.maxWidth < 850;
        final left = _SettingsCard(
          title: 'Core behavior',
          description: 'Keep advanced settings optional and hidden by default.',
          child: Column(
            children: [
              _SwitchRow(
                title: 'System proxy',
                description: 'Configure OS proxy automatically.',
                value: systemProxyEnabled,
                onChanged: (value) => _saveConfig(
                  _currentConfig().copyWith(systemProxyEnabled: value),
                ),
              ),
              const Divider(height: 24),
              _SwitchRow(
                title: 'TUN mode',
                description: 'Route system traffic through a virtual adapter.',
                value: tunEnabled,
                onChanged: (value) =>
                    _saveConfig(_currentConfig().copyWith(tunEnabled: value)),
              ),
              const Divider(height: 24),
              _SwitchRow(
                title: 'Launch at startup',
                description: 'Start minimized with the last profile.',
                value: launchAtStartup,
                onChanged: (value) => _saveConfig(
                  _currentConfig().copyWith(launchAtStartup: value),
                ),
              ),
            ],
          ),
        );

        final right = _SettingsCard(
          title: 'DNS and routing',
          description: 'Expose only the pieces users actually need.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DNS mode',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              SegmentedButton<DnsMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: DnsMode.auto, label: Text('Auto')),
                  ButtonSegment(value: DnsMode.proxy, label: Text('Proxy DNS')),
                  ButtonSegment(
                      value: DnsMode.direct, label: Text('Direct DNS')),
                ],
                selected: <DnsMode>{dnsMode},
                onSelectionChanged: (selection) => _saveConfig(
                  _currentConfig().copyWith(dnsMode: selection.first),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Recommended default: Auto. Keep DNS aligned with routing to avoid leaks and rule mismatches.',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: _refreshState,
                    child: const Text('Refresh state'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _showLogsDialog,
                    child: const Text('Open logs'),
                  ),
                ],
              ),
            ],
          ),
        );

        if (singleColumn) {
          return ListView(
            children: [left, const SizedBox(height: 16), right],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            Expanded(child: right),
          ],
        );
      },
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
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.connection,
    required this.routingMode,
    required this.dnsMode,
    required this.selectedIndex,
    required this.onSelect,
  });

  final ConnectionStateValue connection;
  final RoutingMode routingMode;
  final DnsMode dnsMode;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('Home', Icons.home_outlined),
      ('Rules', Icons.rule_folder_outlined),
      ('Profiles', Icons.dns_outlined),
      ('Settings', Icons.tune_outlined),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF173C4A),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('XR UI',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Minimal Xray client',
                      style: TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 26),
          for (var index = 0; index < items.length; index++) ...[
            _NavButton(
              label: items[index].$1,
              icon: items[index].$2,
              selected: index == selectedIndex,
              onTap: () => onSelect(index),
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.profile,
    required this.connection,
    required this.routingMode,
    required this.proxyCount,
    required this.directCount,
    required this.runtimeRunning,
    required this.runtimeInfo,
    required this.onToggleConnection,
    required this.onModeChanged,
  });

  final ServerProfile profile;
  final ConnectionStateValue connection;
  final RoutingMode routingMode;
  final int proxyCount;
  final int directCount;
  final bool runtimeRunning;
  final String runtimeInfo;
  final Future<void> Function() onToggleConnection;
  final Future<void> Function(RoutingMode) onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(30),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final singleColumn = constraints.maxWidth < 900;

          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current profile',
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
              const SizedBox(height: 8),
              Text(profile.name,
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'Simple Xray dashboard with one-click connect and domain routing lists.',
                style: TextStyle(
                    fontSize: 15, color: Colors.black.withValues(alpha: 0.6)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ChipLabel(label: 'Latency ${profile.latencyMs} ms'),
                  _ChipLabel(
                    label: runtimeRunning ? 'Core running' : 'Core stopped',
                  ),
                  _ChipLabel(label: profile.protocol),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      onToggleConnection();
                    },
                    icon: Icon(
                      connection == ConnectionStateValue.connected
                          ? Icons.power_settings_new_rounded
                          : Icons.flash_on_rounded,
                    ),
                    label: Text(
                      connection == ConnectionStateValue.connected
                          ? 'Disconnect'
                          : 'Connect',
                    ),
                  ),
                  SegmentedButton<RoutingMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: RoutingMode.global, label: Text('Global')),
                      ButtonSegment(
                          value: RoutingMode.whitelist,
                          label: Text('Whitelist')),
                      ButtonSegment(
                          value: RoutingMode.blacklist,
                          label: Text('Blacklist')),
                    ],
                    selected: <RoutingMode>{routingMode},
                    onSelectionChanged: (selection) {
                      onModeChanged(selection.first);
                    },
                  ),
                ],
              ),
            ],
          );

          final stats = Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricCard(
                label: 'Status',
                value: runtimeRunning ? 'Active tunnel' : 'Offline',
                accent: connection == ConnectionStateValue.connected
                    ? const Color(0xFF2C7A5D)
                    : const Color(0xFF9A6A22),
              ),
              _MetricCard(
                label: 'Outbound',
                value: profile.protocol,
                accent: const Color(0xFF0E5E6F),
              ),
              _MetricCard(
                  label: 'Proxy rules',
                  value: '$proxyCount domains',
                  accent: const Color(0xFF173C4A)),
              _MetricCard(
                  label: 'Direct rules',
                  value: '$directCount domains',
                  accent: const Color(0xFF6E5D46)),
              _MetricCard(
                label: 'Core info',
                value: runtimeInfo,
                accent: runtimeRunning
                    ? const Color(0xFF2C7A5D)
                    : const Color(0xFF9A6A22),
              ),
            ],
          );

          if (singleColumn) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [details, const SizedBox(height: 20), stats],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: details),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: stats),
            ],
          );
        },
      ),
    );
  }
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
        color: const Color(0xFFF7F3EC),
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
        color: const Color(0xFFF7F3EC),
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
      color: Colors.white.withValues(alpha: 0.82),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(description,
                style: TextStyle(color: Colors.black.withValues(alpha: 0.6))),
            const SizedBox(height: 18),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF173C4A) : Colors.transparent,
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
