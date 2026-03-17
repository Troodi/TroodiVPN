part of 'main.dart';

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
  bool isConnecting = false;
  String? errorMessage;
  RuntimeSnapshot runtimeStatus = RuntimeSnapshot.empty;

  late final TextEditingController proxyController;
  late final TextEditingController directController;
  late final TextEditingController blockedController;
  late final TextEditingController searchController;
  late final TextEditingController ruleTestController;
  late final TextEditingController vpnSearchController;
  late final TextEditingController directSearchController;
  late final TextEditingController blockedSearchController;

  List<String> proxyDomains = const [];
  List<String> directDomains = const [];
  List<String> blockedDomains = const [];
  List<ServerProfile> profiles = const [];
  final Set<String> disabledVpnRules = <String>{};
  final Set<String> disabledDirectRules = <String>{};
  final Set<String> disabledBlockedRules = <String>{};

  String activeProfileId = '';

  @override
  void initState() {
    super.initState();
    backendRuntime = BackendRuntime(backend);
    proxyController = TextEditingController();
    directController = TextEditingController();
    blockedController = TextEditingController();
    searchController = TextEditingController();
    ruleTestController = TextEditingController();
    vpnSearchController = TextEditingController();
    directSearchController = TextEditingController();
    blockedSearchController = TextEditingController();
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
    ruleTestController.dispose();
    vpnSearchController.dispose();
    directSearchController.dispose();
    blockedSearchController.dispose();
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
                width: 300,
                child: _Sidebar(
                  connection: connection,
                  isConnecting: isConnecting,
                  routingMode: routingMode,
                  dnsMode: dnsMode,
                  latencyMs: runtimeStatus.latencyMs,
                  externalIp: runtimeStatus.publicIp,
                  downloadBps: runtimeStatus.downloadBps,
                  uploadBps: runtimeStatus.uploadBps,
                  hasActiveProfile: hasActiveProfile,
                  activeProfileName: hasActiveProfile ? activeProfile.name : '',
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
      final ready = await _ensureBackendReady(silent: silent);
      if (!ready) {
        return;
      }
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

  Future<bool> _ensureBackendReady({bool silent = false}) async {
    try {
      await backendRuntime.ensureRunning();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }
      if (!silent) {
        setState(() {
          isLoading = false;
          errorMessage = error.toString();
        });
        _showMessage(error.toString(), isError: true);
      }
      return false;
    }
  }

  Future<void> _saveConfig(AppConfigState config) async {
    setState(() {
      isBusy = true;
      errorMessage = null;
    });

    try {
      final ready = await _ensureBackendReady();
      if (!ready) {
        return;
      }
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
    if (connection == ConnectionStateValue.disconnected && !hasActiveProfile) {
      _showMessage('Select or create a profile first.', isError: true);
      return;
    }

    setState(() {
      isBusy = true;
      isConnecting = connection == ConnectionStateValue.disconnected;
      errorMessage = null;
    });

    try {
      final ready = await _ensureBackendReady();
      if (!ready) {
        return;
      }
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
          if (connection == ConnectionStateValue.disconnected) {
            isConnecting = false;
          }
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
    final ready = await _ensureBackendReady();
    if (!ready) {
      return false;
    }

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
    disabledVpnRules.removeWhere((item) => !proxyDomains.contains(item));
    disabledDirectRules.removeWhere((item) => !directDomains.contains(item));
    disabledBlockedRules.removeWhere((item) => !blockedDomains.contains(item));
    profiles = List<ServerProfile>.from(config.profiles);
    activeProfileId = config.activeProfileId;
    runtimeStatus = snapshot.runtime;
    if (connection != ConnectionStateValue.connected) {
      isConnecting = false;
    } else {
      isConnecting = !runtimeStatus.ready;
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
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MainConnectionCard(
                      profileName: hasActiveProfile
                          ? activeProfile.name
                          : 'Select VPN Server',
                      connection: connection,
                      isConnecting: isConnecting,
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
                        await _saveConfig(_currentConfig()
                            .copyWith(activeProfileId: profileId));
                      },
                      tunnelMode: tunnelMode,
                      onTunnelModeChanged: _switchTunnelMode,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildRulesView() {
    final testResult = _testRule(ruleTestController.text);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = [
          _buildRulesColumnCard(
            title: 'Via VPN',
            subtitle: 'Use VPN for these domains',
            counter: proxyDomains.length,
            searchController: vpnSearchController,
            inputController: proxyController,
            placeholder: 'github.com',
            domains: proxyDomains,
            disabledRules: disabledVpnRules,
            accent: const Color(0xFF6CEB86),
            emptyText: 'No VPN rules yet.',
            onAdd: () => _addDomain(
              proxyController,
              proxyDomains,
              (items) =>
                  _saveConfig(_currentConfig().copyWith(proxyDomains: items)),
            ),
            onPaste: () => _pasteRuleList(
              proxyDomains,
              (items) =>
                  _saveConfig(_currentConfig().copyWith(proxyDomains: items)),
            ),
            onRemove: (domain) => _saveConfig(
              _currentConfig().copyWith(
                proxyDomains:
                    proxyDomains.where((item) => item != domain).toList(),
              ),
            ),
            onToggleRule: (domain, enabled) {
              setState(() {
                if (enabled) {
                  disabledVpnRules.remove(domain);
                } else {
                  disabledVpnRules.add(domain);
                }
              });
            },
          ),
          _buildRulesColumnCard(
            title: 'Open normally',
            subtitle: 'Bypass VPN for these domains',
            counter: directDomains.length,
            searchController: directSearchController,
            inputController: directController,
            placeholder: 'bank.ru',
            domains: directDomains,
            disabledRules: disabledDirectRules,
            accent: const Color(0xFF8EA2FF),
            emptyText: 'No direct rules yet.',
            onAdd: () => _addDomain(
              directController,
              directDomains,
              (items) =>
                  _saveConfig(_currentConfig().copyWith(directDomains: items)),
            ),
            onPaste: () => _pasteRuleList(
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
            onToggleRule: (domain, enabled) {
              setState(() {
                if (enabled) {
                  disabledDirectRules.remove(domain);
                } else {
                  disabledDirectRules.add(domain);
                }
              });
            },
          ),
          _buildRulesColumnCard(
            title: 'Blocked',
            subtitle: 'Drop traffic for these domains',
            counter: blockedDomains.length,
            searchController: blockedSearchController,
            inputController: blockedController,
            placeholder: 'ads.example.com',
            domains: blockedDomains,
            disabledRules: disabledBlockedRules,
            accent: const Color(0xFFFF9E8B),
            emptyText: 'No blocked rules yet.',
            onAdd: () => _addDomain(
              blockedController,
              blockedDomains,
              (items) =>
                  _saveConfig(_currentConfig().copyWith(blockedDomains: items)),
            ),
            onPaste: () => _pasteRuleList(
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
            onToggleRule: (domain, enabled) {
              setState(() {
                if (enabled) {
                  disabledBlockedRules.remove(domain);
                } else {
                  disabledBlockedRules.add(domain);
                }
              });
            },
          ),
        ];

        final conflicts = _findRuleConflicts();

        final listChildren = <Widget>[
          _RulesModeCard(
            routingMode: routingMode,
            onModeChanged: (value) =>
                _saveConfig(_currentConfig().copyWith(routingMode: value)),
          ),
          const SizedBox(height: 16),
          _RoutingTreeCard(
            routingMode: routingMode,
            vpnDomains: _enabledRules(proxyDomains, disabledVpnRules),
            directDomains: _enabledRules(directDomains, disabledDirectRules),
          ),
          const SizedBox(height: 16),
          _RulesVisualizationCard(
            routingMode: routingMode,
            vpnDomains: _enabledRules(proxyDomains, disabledVpnRules),
            directDomains: _enabledRules(directDomains, disabledDirectRules),
            blockedDomains: _enabledRules(blockedDomains, disabledBlockedRules),
          ),
          const SizedBox(height: 16),
          _RuleTesterCard(
            controller: ruleTestController,
            result: testResult,
            onChanged: () => setState(() {}),
          ),
          if (conflicts.isNotEmpty) ...[
            const SizedBox(height: 16),
            _RuleConflictsCard(conflicts: conflicts),
          ],
          const SizedBox(height: 16),
        ];

        if (constraints.maxWidth >= 1100) {
          listChildren.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: columns[0]),
                const SizedBox(width: 16),
                Expanded(child: columns[1]),
                const SizedBox(width: 16),
                Expanded(child: columns[2]),
              ],
            ),
          );
        } else if (constraints.maxWidth >= 760) {
          listChildren.add(
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 0.9,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: columns,
            ),
          );
        } else {
          listChildren.addAll([
            columns[0],
            const SizedBox(height: 16),
            columns[1],
            const SizedBox(height: 16),
            columns[2],
          ]);
        }

        listChildren.addAll([
          const SizedBox(height: 16),
          _RulesQuickActionsCard(
            onReset: _resetRules,
            onRestoreRecommended: _restoreRecommendedRules,
          ),
        ]);

        return ListView(
          children: listChildren,
        );
      },
    );
  }

  Widget _buildRulesColumnCard({
    required String title,
    required String subtitle,
    required int counter,
    required TextEditingController searchController,
    required TextEditingController inputController,
    required String placeholder,
    required List<String> domains,
    required Set<String> disabledRules,
    required Color accent,
    required String emptyText,
    required Future<void> Function() onAdd,
    required Future<void> Function() onPaste,
    required Future<void> Function(String) onRemove,
    required void Function(String domain, bool enabled) onToggleRule,
  }) {
    final query = searchController.text.trim().toLowerCase();
    final filtered =
        domains.where((item) => item.toLowerCase().contains(query)).toList();

    return SizedBox(
      height: 560,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [AppShadows.darkCard],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$title ($counter)',
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.96),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$counter rules',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: inputController,
                      onSubmitted: (_) => onAdd(),
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.94),
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: placeholder,
                        hintStyle: TextStyle(
                          color:
                              AppPalette.homeTextMuted.withValues(alpha: 0.90),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add'),
                    style: AppUi.primaryButton(accent),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onPaste,
                    icon: const Icon(Icons.content_paste_rounded, size: 16),
                    label: const Text('Paste list'),
                    style: FilledButton.styleFrom(
                      foregroundColor: AppPalette.homeText,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(
                  color: AppPalette.homeText.withValues(alpha: 0.94),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Search rules...',
                  hintStyle: TextStyle(
                    color: AppPalette.homeTextMuted.withValues(alpha: 0.90),
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Text(
                    'Supported formats',
                    style: TextStyle(
                      color: AppPalette.homeTextMuted.withValues(alpha: 0.78),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  for (final item in const [
                    'example.com',
                    '*.example.com',
                    '1.1.1.1',
                    '192.168.0.0/24',
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        item,
                        style: TextStyle(
                          color:
                              AppPalette.homeTextMuted.withValues(alpha: 0.78),
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 280,
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          emptyText,
                          style: TextStyle(
                            color: AppPalette.homeTextMuted
                                .withValues(alpha: 0.72),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final domain = filtered[index];
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: disabledRules.contains(domain)
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.public_rounded,
                                    size: 16, color: accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    domain,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: disabledRules.contains(domain)
                                          ? AppPalette.homeTextMuted
                                              .withValues(alpha: 0.58)
                                          : AppPalette.homeText
                                              .withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      decoration: disabledRules.contains(domain)
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                ),
                                _RuleTypeBadge(rule: domain),
                                const SizedBox(width: 4),
                                Switch(
                                  value: !disabledRules.contains(domain),
                                  onChanged: (value) =>
                                      onToggleRule(domain, value),
                                ),
                                IconButton(
                                  onPressed: () => onRemove(domain),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18),
                                  color: AppPalette.homeTextMuted
                                      .withValues(alpha: 0.86),
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
      ),
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

  Future<void> _pasteRuleList(
    List<String> current,
    Future<void> Function(List<String>) apply,
  ) async {
    final raw = await _showPasteRulesDialog();
    if (raw == null || raw.trim().isEmpty) return;

    final merged = <String>[...current];
    for (final line in raw.split(RegExp(r'[\r\n,;]+'))) {
      final value = _normalizeDomain(line);
      if (value.isNotEmpty && !merged.contains(value)) {
        merged.add(value);
      }
    }

    await apply(merged);
    if (mounted) {
      _showMessage('Rules pasted from clipboard.');
    }
  }

  Future<String?> _showPasteRulesDialog() async {
    final controller = TextEditingController();
    final clipboard = await Clipboard.getData('text/plain');
    controller.text = clipboard?.text?.trim() ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Paste list'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supported formats',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 8),
              const SelectableText(
                'example.com\n*.example.com\n1.1.1.1\n192.168.0.0/24',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                minLines: 8,
                maxLines: 12,
                decoration: const InputDecoration(
                  hintText: 'youtube.com\ngooglevideo.com\nytimg.com',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _resetRules() async {
    await _saveConfig(
      _currentConfig().copyWith(
        proxyDomains: const [],
        directDomains: const [],
        blockedDomains: const [],
      ),
    );
  }

  Future<void> _restoreRecommendedRules() async {
    await _saveConfig(
      _currentConfig().copyWith(
        proxyDomains: const [
          'github.com',
          'openai.com',
          'chatgpt.com',
        ],
        directDomains: const [
          'bank.ru',
          'gosuslugi.ru',
          'localhost',
        ],
        blockedDomains: const [
          'doubleclick.net',
        ],
      ),
    );
  }

  _RuleTestResult _testRule(String raw) {
    final value = _normalizeDomain(raw);
    if (value.isEmpty) {
      return const _RuleTestResult.empty();
    }

    final enabledBlocked = _enabledRules(blockedDomains, disabledBlockedRules);
    final enabledVpn = _enabledRules(proxyDomains, disabledVpnRules);
    final enabledDirect = _enabledRules(directDomains, disabledDirectRules);

    for (final item in enabledBlocked) {
      if (_ruleMatches(item, value)) {
        return _RuleTestResult(
          input: value,
          destination: 'Blocked',
          matchedRule: item,
          accent: const Color(0xFFFF9E8B),
          hasMatch: true,
        );
      }
    }

    if (routingMode == RoutingMode.whitelist) {
      for (final item in enabledVpn) {
        if (_ruleMatches(item, value)) {
          return _RuleTestResult(
            input: value,
            destination: 'Via VPN',
            matchedRule: item,
            accent: const Color(0xFF6CEB86),
            hasMatch: true,
          );
        }
      }
      return _RuleTestResult(
        input: value,
        destination: 'Open normally',
        matchedRule: 'No matching rules',
        accent: const Color(0xFF8EA2FF),
        hasMatch: false,
      );
    }

    for (final item in enabledDirect) {
      if (_ruleMatches(item, value)) {
        return _RuleTestResult(
          input: value,
          destination: 'Open normally',
          matchedRule: item,
          accent: const Color(0xFF8EA2FF),
          hasMatch: true,
        );
      }
    }

    if (routingMode == RoutingMode.blacklist ||
        routingMode == RoutingMode.global) {
      return _RuleTestResult(
        input: value,
        destination: 'Via VPN',
        matchedRule: 'No matching rules',
        accent: const Color(0xFF6CEB86),
        hasMatch: false,
      );
    }

    return const _RuleTestResult.empty();
  }

  List<String> _enabledRules(List<String> rules, Set<String> disabledRules) {
    return rules.where((item) => !disabledRules.contains(item)).toList();
  }

  List<String> _findRuleConflicts() {
    final conflicts = <String>{};
    final vpn = _enabledRules(proxyDomains, disabledVpnRules);
    final direct = _enabledRules(directDomains, disabledDirectRules);
    final blocked = _enabledRules(blockedDomains, disabledBlockedRules);

    for (final rule in vpn) {
      if (direct.any((item) => _rulesOverlap(rule, item))) {
        conflicts.add('$rule conflicts between Via VPN and Open normally');
      }
      if (blocked.any((item) => _rulesOverlap(rule, item))) {
        conflicts.add('$rule conflicts between Via VPN and Blocked');
      }
    }

    for (final rule in direct) {
      if (blocked.any((item) => _rulesOverlap(rule, item))) {
        conflicts.add('$rule conflicts between Open normally and Blocked');
      }
    }

    return conflicts.toList();
  }

  bool _rulesOverlap(String left, String right) {
    final a = _normalizeDomain(left);
    final b = _normalizeDomain(right);
    if (a == b) return true;
    if (a.startsWith('*.') &&
        (b == a.substring(2) || b.endsWith('.${a.substring(2)}'))) {
      return true;
    }
    if (b.startsWith('*.') &&
        (a == b.substring(2) || a.endsWith('.${b.substring(2)}'))) {
      return true;
    }
    return false;
  }

  bool _ruleMatches(String rule, String value) {
    final normalizedRule = _normalizeDomain(rule);
    if (normalizedRule.isEmpty) {
      return false;
    }
    if (normalizedRule == value) {
      return true;
    }
    if (normalizedRule.startsWith('*.')) {
      return value == normalizedRule.substring(2) ||
          value.endsWith('.${normalizedRule.substring(2)}');
    }
    return value.endsWith('.$normalizedRule');
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
