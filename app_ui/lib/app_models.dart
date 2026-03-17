part of 'main.dart';

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
    required this.publicIp,
    required this.downloadBps,
    required this.uploadBps,
    required this.ready,
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
    publicIp: '',
    downloadBps: 0,
    uploadBps: 0,
    ready: false,
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
  final String publicIp;
  final int downloadBps;
  final int uploadBps;
  final bool ready;
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
      publicIp: json['publicIp'] as String? ?? '',
      downloadBps: json['downloadBps'] as int? ?? 0,
      uploadBps: json['uploadBps'] as int? ?? 0,
      ready: json['ready'] as bool? ?? false,
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
