part of 'main.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final BackendClient backend = const BackendClient();
  late final BackendRuntime backendRuntime;
  Timer? pollTimer;
  bool isRefreshing = false;

  ConnectionStateValue connection = ConnectionStateValue.disconnected;
  RoutingMode routingMode = RoutingMode.global;
  RulesProfile rulesProfile = RulesProfile.global;
  DnsMode dnsMode = DnsMode.auto;
  bool systemProxyEnabled = true;
  bool tunEnabled = false;
  bool launchAtStartup = true;
  bool autoCheckUpdates = false;
  AppLanguage appLanguage = AppLanguage.ru;
  ProfilesWorkspaceMode profilesWorkspaceMode = ProfilesWorkspaceMode.add;
  AppPage selectedPage = AppPage.home;
  bool isLoading = true;
  bool isBusy = false;
  bool isConnecting = false;
  bool isElevationInProgress = false;
  bool isSwitchingTunnelMode = false;
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
  String? vpnInputError;
  String? directInputError;
  String? blockedInputError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      if (isElevationInProgress) {
        return;
      }
      _refreshState(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(backendRuntime.dispose());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    _activeLanguage = appLanguage;
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
                  Positioned(
                    top: 22,
                    right: 22,
                    child: IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF11172F).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            AppShadows.darkCard,
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.1,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              tr('Applying...'),
                              style: TextStyle(
                                color: AppPalette.homeText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                  Text(
                    tr('Backend unavailable'),
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
                    label: Text(tr('Retry')),
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
                  language: appLanguage,
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
                  onLanguageChanged: (language) {
                    setState(() {
                      appLanguage = language;
                    });
                  },
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
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              label: loc(appLanguage, 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.rule_folder_outlined),
              label: loc(appLanguage, 'Rules'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.dns_outlined),
              label: loc(appLanguage, 'Profiles'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              label: loc(appLanguage, 'Settings'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _refreshState({bool silent = false}) async {
    if (isRefreshing || isBusy || isElevationInProgress) {
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
    if (isElevationInProgress) {
      return false;
    }
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

  Future<void> _saveConfig(
    AppConfigState config, {
    bool preserveConnection = true,
  }) async {
    final wasConnectedBeforeChange =
        connection == ConnectionStateValue.connected;
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

      if (preserveConnection &&
          wasConnectedBeforeChange &&
          connection == ConnectionStateValue.disconnected) {
        final assetsBusy = snapshot.runtime.routingAssetsStatus == 'downloading';
        final assetsFailed = snapshot.runtime.routingAssetsStatus == 'error' &&
            snapshot.runtime.russiaRoutingAssetsUpdatedAt.isEmpty;
        if (assetsBusy || assetsFailed) {
          _showMessage(
            assetsBusy
                ? tr('Waiting for routing rules download before reconnecting.')
                : tr('Routing rules download failed. Retry and reconnect.'),
            isError: assetsFailed,
          );
        } else {
          await _restoreConnectionAfterConfigChange();
        }
      }
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      _showMessage(
        tr('Backend did not respond in time. The change may still apply shortly.'),
        isError: true,
      );
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

  Future<void> _restoreConnectionAfterConfigChange() async {
    if (!mounted || !hasActiveProfile) {
      return;
    }
    try {
      final reconnect = await backend.connect();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySnapshot(reconnect);
      });
      if (reconnect.config.connectionState == ConnectionStateValue.connected) {
        _showMessage(tr('Connection restored after applying changes.'));
      } else {
        _showMessage(
          tr('Reconnection is pending. Complete rule download, then retry.'),
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
        tr('Reconnection failed after applying changes. Tap Connect to retry.'),
        isError: true,
      );
    }
  }

  Future<void> _toggleConnection() async {
    if (connection == ConnectionStateValue.disconnected && !hasActiveProfile) {
      _showMessage(
        tr('Select or create a profile first.'),
        isError: true,
      );
      return;
    }

    if (connection == ConnectionStateValue.disconnected &&
        tunnelMode == TunnelMode.vpn) {
      final elevated = await _ensureAdminForTun();
      if (!elevated) {
        return;
      }
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

      if (connection == ConnectionStateValue.disconnected &&
          rulesProfile == RulesProfile.russia) {
        var snap = await backend.getState();
        if (!mounted) {
          return;
        }
        setState(() {
          _applySnapshot(snap);
        });
        if (!_russiaRulesDataReady(snap.runtime)) {
          final ok = await _showRussiaRulesFirstDownloadDialog(
            cancelRevertsProfileToGlobal: false,
          );
          if (!ok || !mounted) {
            return;
          }
          snap = await backend.getState();
          if (!mounted) {
            return;
          }
          setState(() {
            _applySnapshot(snap);
          });
          if (!_russiaRulesDataReady(snap.runtime)) {
            _showMessage(
              loc(appLanguage, 'Could not download routing rules.'),
              isError: true,
            );
            return;
          }
        }
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
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      _showMessage(
        tr('Connection is taking too long. Check Logs. If Xray starts, the status will update automatically.'),
        isError: true,
      );
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
    if (mode == tunnelMode || isSwitchingTunnelMode || isBusy) {
      return;
    }

    final wasConnected = connection == ConnectionStateValue.connected;

    setState(() {
      isSwitchingTunnelMode = true;
    });

    try {
      if (mode == TunnelMode.vpn) {
        if (wasConnected) {
          final elevated = await _ensureAdminForTun();
          if (!elevated) {
            return;
          }
        }
        await _saveConfig(
          _currentConfig().copyWith(
            tunEnabled: true,
            systemProxyEnabled: false,
          ),
        );
      } else {
        await _saveConfig(
          _currentConfig().copyWith(
            tunEnabled: false,
            systemProxyEnabled: true,
          ),
        );
      }

      if (!mounted) {
        return;
      }
      if (wasConnected &&
          connection == ConnectionStateValue.disconnected) {
        await _reconnectAfterTunnelModeChange();
      }
    } finally {
      if (mounted) {
        setState(() {
          isSwitchingTunnelMode = false;
        });
      }
    }
  }

  Future<void> _reconnectAfterTunnelModeChange() async {
    setState(() {
      isBusy = true;
      isConnecting = true;
      errorMessage = null;
    });
    try {
      final ready = await _ensureBackendReady();
      if (!ready) {
        return;
      }
      final snapshot = await backend.connect();
      if (!mounted) {
        return;
      }
      setState(() {
        _applySnapshot(snapshot);
      });
    } on TimeoutException {
      if (mounted) {
        _showMessage(
          tr('Connection is taking too long. Check Logs. If Xray starts, the status will update automatically.'),
          isError: true,
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(error.toString(), isError: true);
      }
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

  Future<bool> _ensureAdminForTun() async {
    final ready = await _ensureBackendReady();
    if (!ready) {
      return false;
    }

    final elevated = runtimeStatus.elevated || await backend.getAdminStatus();
    if (elevated) {
      return true;
    }

    if (Platform.isLinux) {
      final password = await _showLinuxSudoDialog();
      if (password == null || password.isEmpty) {
        return false;
      }

      try {
        await backend.requestAdmin(password);
        final snapshot = await backend.getState();
        if (!mounted) {
          return false;
        }
        setState(() {
          _applySnapshot(snapshot);
          errorMessage = null;
        });
        return true;
      } catch (error) {
        if (mounted) {
          _showMessage(error.toString(), isError: true);
        }
        return false;
      }
    }

    try {
      if (mounted) {
        setState(() {
          isElevationInProgress = true;
        });
      }
      await backend.requestAdmin();
    } catch (error) {
      final message = error.toString().toLowerCase();
      final reconnectExpected = message.contains('socket') ||
          message.contains('connection') ||
          message.contains('connection reset');
      if (!reconnectExpected) {
        if (mounted) {
          setState(() {
            isElevationInProgress = false;
          });
          _showMessage(error.toString(), isError: true);
        }
        return false;
      }
    }

    if (mounted) {
      _showMessage(tr(
          'Approve the administrator prompt. Waiting for elevated backend...'));
    }

    for (var attempt = 0; attempt < 20; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      try {
        final snapshot = await backend.getState();
        if (snapshot.runtime.elevated) {
          if (mounted) {
            setState(() {
              isElevationInProgress = false;
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
      setState(() {
        isElevationInProgress = false;
      });
      _showMessage(tr('Failed to reconnect to an elevated backend.'),
          isError: true);
    }
    return false;
  }

  Future<String?> _showLinuxSudoDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return _LinuxSudoDialog(controller: controller);
        },
      );
    } finally {
      controller.dispose();
    }
  }

  void _applySnapshot(DashboardSnapshot snapshot) {
    final config = snapshot.config;
    connection = config.connectionState;
    routingMode = config.routingMode;
    rulesProfile = config.rulesProfile;
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
      rulesProfile: rulesProfile,
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
      if (runtimeStatus.logs.isEmpty) tr('No logs captured yet.'),
      ...runtimeStatus.logs,
    ];

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(tr('Xray logs')),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: SelectableText(logLines.join('\n')),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr('Close')),
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
                          : loc(appLanguage, 'Select VPN Server'),
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
                        title: loc(appLanguage, 'No profile selected'),
                        description: loc(
                          appLanguage,
                          'Open Profiles, import or create a profile, then select it on this screen.',
                        ),
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
    final vpnRules = _rulesForBucket(RuleBucket.vpn);
    final directRules = _rulesForBucket(RuleBucket.direct);
    final blockedRules = _rulesForBucket(RuleBucket.blocked);

    return LayoutBuilder(
      builder: (context, constraints) {
        final listChildren = <Widget>[
          _RulesModeCard(
            routingMode: routingMode,
            rulesProfile: rulesProfile,
            language: appLanguage,
            russiaRulesFailed: runtimeStatus.routingAssetsStatus == 'error',
            russiaRulesUpdatedAt: runtimeStatus.russiaRoutingAssetsUpdatedAt,
            onModeChanged: (value) =>
                _saveConfig(_currentConfig().copyWith(routingMode: value)),
            onProfileChanged: (profile) async {
              if (rulesProfile == profile) {
                return;
              }
              await _applyRulesProfile(profile);
            },
          ).animate().fadeIn(duration: 240.ms).slideY(
                begin: 0.05,
                end: 0,
                duration: 280.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 16),
          _TrafficBehaviorCard(
            routingMode: routingMode,
            vpnCount: vpnRules.where((rule) => rule.enabled).length,
            directCount: directRules.where((rule) => rule.enabled).length,
            blockedCount: blockedRules.where((rule) => rule.enabled).length,
            onViewDetails: _showRoutingDetailsDialog,
          ).animate().fadeIn(delay: 80.ms, duration: 240.ms).slideY(
                begin: 0.05,
                end: 0,
                delay: 80.ms,
                duration: 280.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 16),
          _DomainTestCard(
            controller: ruleTestController,
            result: testResult,
            onChanged: () => setState(() {}),
          ).animate().fadeIn(delay: 140.ms, duration: 240.ms).slideY(
                begin: 0.05,
                end: 0,
                delay: 140.ms,
                duration: 280.ms,
                curve: Curves.easeOutCubic,
              ),
          const SizedBox(height: 16),
        ];

        final List<Widget> columns = [
          _RulesColumnCard(
            title: tr('Via VPN'),
            subtitle: tr('Use VPN for these domains'),
            placeholder: 'github.com',
            accent: const Color(0xFF68D6A1),
            rules: vpnRules,
            errorText: vpnInputError,
            searchController: vpnSearchController,
            inputController: proxyController,
            emptyText: tr('No VPN rules yet.'),
            onChanged: () => setState(() {}),
            onAdd: () => _addRuleToBucket(RuleBucket.vpn),
            onPaste: () => _pasteRulesToBucket(RuleBucket.vpn),
            onToggleRule: (value, enabled) =>
                _setRuleEnabled(RuleBucket.vpn, value, enabled),
            onDeleteRule: (value) =>
                _removeRuleFromBucket(RuleBucket.vpn, value),
            onEditRule: (rule) => _editRule(rule),
          ),
          _RulesColumnCard(
            title: tr('Open normally'),
            subtitle: tr('Bypass VPN for these domains'),
            placeholder: 'bank.ru',
            accent: const Color(0xFF97A8FF),
            rules: directRules,
            errorText: directInputError,
            searchController: directSearchController,
            inputController: directController,
            emptyText: tr('No direct rules yet.'),
            onChanged: () => setState(() {}),
            onAdd: () => _addRuleToBucket(RuleBucket.direct),
            onPaste: () => _pasteRulesToBucket(RuleBucket.direct),
            onToggleRule: (value, enabled) =>
                _setRuleEnabled(RuleBucket.direct, value, enabled),
            onDeleteRule: (value) =>
                _removeRuleFromBucket(RuleBucket.direct, value),
            onEditRule: (rule) => _editRule(rule),
          ),
          _RulesColumnCard(
            title: tr('Blocked'),
            subtitle: tr('Drop traffic for these domains'),
            placeholder: 'ads.example.com',
            accent: const Color(0xFFFF9E8B),
            rules: blockedRules,
            errorText: blockedInputError,
            searchController: blockedSearchController,
            inputController: blockedController,
            emptyText: tr('No blocked rules yet.'),
            onChanged: () => setState(() {}),
            onAdd: () => _addRuleToBucket(RuleBucket.blocked),
            onPaste: () => _pasteRulesToBucket(RuleBucket.blocked),
            onToggleRule: (value, enabled) =>
                _setRuleEnabled(RuleBucket.blocked, value, enabled),
            onDeleteRule: (value) =>
                _removeRuleFromBucket(RuleBucket.blocked, value),
            onEditRule: (rule) => _editRule(rule),
          ),
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
            ).animate().fadeIn(delay: 220.ms, duration: 260.ms).slideY(
                  begin: 0.04,
                  end: 0,
                  delay: 220.ms,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
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
            ).animate().fadeIn(delay: 220.ms, duration: 260.ms).slideY(
                  begin: 0.04,
                  end: 0,
                  delay: 220.ms,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
          );
        } else {
          listChildren.addAll([
            columns[0].animate().fadeIn(delay: 220.ms, duration: 260.ms).slideY(
                  begin: 0.04,
                  end: 0,
                  delay: 220.ms,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 16),
            columns[1].animate().fadeIn(delay: 280.ms, duration: 260.ms).slideY(
                  begin: 0.04,
                  end: 0,
                  delay: 280.ms,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
            const SizedBox(height: 16),
            columns[2].animate().fadeIn(delay: 340.ms, duration: 260.ms).slideY(
                  begin: 0.04,
                  end: 0,
                  delay: 340.ms,
                  duration: 300.ms,
                  curve: Curves.easeOutCubic,
                ),
          ]);
        }

        return ListView(
          children: listChildren,
        );
      },
    );
  }

  List<RoutingRule> _rulesForBucket(RuleBucket bucket) {
    final values = _rulesForBucketValues(bucket);
    final disabled = _disabledRulesForBucket(bucket);
    return [
      for (final value in values)
        RoutingRule(
          value: value,
          type: _detectRuleType(value) ?? RuleType.domain,
          bucket: bucket,
          enabled: !disabled.contains(value),
        ),
    ];
  }

  List<String> _rulesForBucketValues(RuleBucket bucket) {
    switch (bucket) {
      case RuleBucket.vpn:
        return proxyDomains;
      case RuleBucket.direct:
        return directDomains;
      case RuleBucket.blocked:
        return blockedDomains;
    }
  }

  Set<String> _disabledRulesForBucket(RuleBucket bucket) {
    switch (bucket) {
      case RuleBucket.vpn:
        return disabledVpnRules;
      case RuleBucket.direct:
        return disabledDirectRules;
      case RuleBucket.blocked:
        return disabledBlockedRules;
    }
  }

  TextEditingController _inputControllerForBucket(RuleBucket bucket) {
    switch (bucket) {
      case RuleBucket.vpn:
        return proxyController;
      case RuleBucket.direct:
        return directController;
      case RuleBucket.blocked:
        return blockedController;
    }
  }

  void _setInputError(RuleBucket bucket, String? value) {
    setState(() {
      switch (bucket) {
        case RuleBucket.vpn:
          vpnInputError = value;
        case RuleBucket.direct:
          directInputError = value;
        case RuleBucket.blocked:
          blockedInputError = value;
      }
    });
  }

  Future<void> _replaceRulesForBucket(
      RuleBucket bucket, List<String> items) async {
    switch (bucket) {
      case RuleBucket.vpn:
        await _saveConfig(_currentConfig().copyWith(proxyDomains: items));
      case RuleBucket.direct:
        await _saveConfig(_currentConfig().copyWith(directDomains: items));
      case RuleBucket.blocked:
        await _saveConfig(_currentConfig().copyWith(blockedDomains: items));
    }
  }

  Future<void> _addRuleToBucket(RuleBucket bucket) async {
    final controller = _inputControllerForBucket(bucket);
    final normalized = _normalizeRuleValue(controller.text);
    final validationError = _validateRuleValue(normalized);
    final current = _rulesForBucketValues(bucket);

    if (validationError != null) {
      _setInputError(bucket, validationError);
      return;
    }
    if (current.contains(normalized)) {
      _setInputError(bucket, tr('This rule already exists in the list.'));
      return;
    }

    await _replaceRulesForBucket(bucket, [normalized, ...current]);
    controller.clear();
    _setInputError(bucket, null);
  }

  Future<void> _removeRuleFromBucket(RuleBucket bucket, String value) async {
    final next = _rulesForBucketValues(bucket)
        .where((item) => item != value)
        .toList(growable: false);
    await _replaceRulesForBucket(bucket, next);
  }

  Future<void> _editRule(RoutingRule rule) async {
    final controller = TextEditingController(text: rule.value);
    final nextValue = await showDialog<String>(
      context: context,
      builder: (context) => _EditRuleDialog(
        title: _bucketTitle(rule.bucket),
        initialValue: rule.value,
        controller: controller,
        normalizeRule: _normalizeRuleValue,
        validateRule: _validateRuleValue,
      ),
    );
    controller.dispose();

    if (nextValue == null || nextValue == rule.value) {
      return;
    }

    final current = List<String>.from(_rulesForBucketValues(rule.bucket));
    if (current.contains(nextValue)) {
      _showMessage(
          tr('This rule already exists in ${_bucketTitle(rule.bucket)}.'));
      return;
    }

    final updated = [
      for (final item in current) item == rule.value ? nextValue : item,
    ];
    await _replaceRulesForBucket(rule.bucket, updated);

    final disabled = _disabledRulesForBucket(rule.bucket);
    setState(() {
      final wasDisabled = disabled.remove(rule.value);
      if (wasDisabled) {
        disabled.add(nextValue);
      }
    });

    if (!mounted) {
      return;
    }
    _showMessage(tr('Rule updated.'));
  }

  void _setRuleEnabled(RuleBucket bucket, String value, bool enabled) {
    final disabled = _disabledRulesForBucket(bucket);
    setState(() {
      if (enabled) {
        disabled.remove(value);
      } else {
        disabled.add(value);
      }
    });
  }

  Future<void> _pasteRulesToBucket(RuleBucket bucket) async {
    final result = await showDialog<_PasteListResult>(
      context: context,
      builder: (context) => _PasteListDialog(
        bucket: bucket,
        title: _bucketTitle(bucket),
        normalizeRule: _normalizeRuleValue,
        validateRule: _validateRuleValue,
      ),
    );
    if (result == null) {
      return;
    }

    final current = _rulesForBucketValues(bucket);
    final merged = <String>[...current];
    var addedCount = 0;
    for (final value in result.validRules) {
      if (!merged.contains(value)) {
        merged.add(value);
        addedCount++;
      }
    }

    await _replaceRulesForBucket(bucket, merged);
    if (!mounted) {
      return;
    }

    if (result.invalidLines.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => _PasteListSummaryDialog(
          addedCount: addedCount,
          invalidLines: result.invalidLines,
        ),
      );
      return;
    }

    _showMessage(
        addedCount == 1 ? tr('1 rule added.') : tr('$addedCount rules added.'));
  }

  Future<void> _confirmResetRules() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogShell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Reset rules'),
              style: TextStyle(
                color: AppPalette.homeText.withValues(alpha: 0.96),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('This will clear Via VPN, Open normally, and Blocked lists.'),
              style: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _DialogSecondaryButton(
                  label: tr('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 10),
                _DialogPrimaryButton(
                  label: tr('Reset'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _resetRules();
    }
  }

  Future<void> _showRoutingDetailsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _RoutingDetailsDialog(
        routingMode: routingMode,
        vpnRules: _rulesForBucket(RuleBucket.vpn)
            .where((rule) => rule.enabled)
            .toList(growable: false),
        directRules: _rulesForBucket(RuleBucket.direct)
            .where((rule) => rule.enabled)
            .toList(growable: false),
        blockedRules: _rulesForBucket(RuleBucket.blocked)
            .where((rule) => rule.enabled)
            .toList(growable: false),
      ),
    );
  }

  String _bucketTitle(RuleBucket bucket) {
    switch (bucket) {
      case RuleBucket.vpn:
        return tr('Via VPN');
      case RuleBucket.direct:
        return tr('Open normally');
      case RuleBucket.blocked:
        return tr('Blocked');
    }
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
        final contentWidth = constraints.maxWidth >= 1200
            ? constraints.maxWidth
            : constraints.maxWidth;
        final profileRows = filteredProfiles;

        Widget workspaceBody;
        switch (profilesWorkspaceMode) {
          case ProfilesWorkspaceMode.add:
            workspaceBody = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, inner) {
                    final isWide = inner.maxWidth >= 980;
                    final cards = [
                      _ProfileActionCard(
                        icon: Icons.content_paste_rounded,
                        title: tr('Import from clipboard'),
                        description: tr(
                          'Paste one or several VPN links and add profiles instantly.',
                        ),
                        primaryLabel: tr('Paste link'),
                        onPressed: _importProfileFromClipboard,
                      ).animate().fadeIn(duration: 240.ms).slideY(
                            begin: 0.04,
                            end: 0,
                            duration: 280.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      _ProfileActionCard(
                        icon: Icons.upload_file_rounded,
                        title: tr('Import file'),
                        description: tr(
                          'Load configuration from a local .txt or .json file.',
                        ),
                        primaryLabel: tr('Upload file'),
                        onPressed: _importProfilesFromFile,
                      ).animate().fadeIn(delay: 70.ms, duration: 240.ms).slideY(
                            begin: 0.04,
                            end: 0,
                            delay: 70.ms,
                            duration: 280.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      _ProfileActionCard(
                        icon: Icons.edit_note_rounded,
                        title: tr('Manual import'),
                        description: tr(
                          'Fill the fields manually and add a VPN profile.',
                        ),
                        primaryLabel: tr('Add manually'),
                        onPressed: _showManualProfileImportDialog,
                      )
                          .animate()
                          .fadeIn(delay: 140.ms, duration: 240.ms)
                          .slideY(
                            begin: 0.04,
                            end: 0,
                            delay: 140.ms,
                            duration: 280.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ];

                    if (isWide) {
                      return Row(
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[1]),
                          const SizedBox(width: 16),
                          Expanded(child: cards[2]),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        cards[0],
                        const SizedBox(height: 16),
                        cards[1],
                        const SizedBox(height: 16),
                        cards[2],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                _ProfilesSectionHeader(
                  title: tr('Added profiles'),
                  trailing: SizedBox(
                    width: constraints.maxWidth > 920 ? 320 : double.infinity,
                    child: TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: tr('Search profiles, SNI or address'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 190.ms, duration: 220.ms),
                const SizedBox(height: 12),
                if (profileRows.isEmpty)
                  _HintCard(
                    title: tr('No profiles yet'),
                    description: tr(
                      'Import a profile from clipboard or add it manually to start.',
                    ),
                    icon: Icons.account_tree_outlined,
                  ).animate().fadeIn(delay: 230.ms, duration: 220.ms).slideY(
                        begin: 0.03,
                        end: 0,
                        delay: 230.ms,
                        duration: 260.ms,
                        curve: Curves.easeOutCubic,
                      )
                else ...[
                  for (var index = 0; index < profileRows.length; index++) ...[
                    _ProfileRowCard(
                      profile: profileRows[index],
                      isActive: profileRows[index].id == activeProfileId,
                      onUse: () => _saveConfig(
                        _currentConfig().copyWith(
                          activeProfileId: profileRows[index].id,
                        ),
                      ),
                      onDetails: () =>
                          _showEditProfileDialog(profileRows[index]),
                      onDelete: () => _removeProfile(profileRows[index].id),
                    )
                        .animate()
                        .fadeIn(
                          delay: Duration(milliseconds: 230 + (index * 55)),
                          duration: 220.ms,
                        )
                        .slideY(
                          begin: 0.03,
                          end: 0,
                          delay: Duration(milliseconds: 230 + (index * 55)),
                          duration: 260.ms,
                          curve: Curves.easeOutCubic,
                        ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            );
          case ProfilesWorkspaceMode.export:
            workspaceBody = _ProfilesExportPanel(
              profiles: profileRows,
              searchController: searchController,
              onSearchChanged: (_) => setState(() {}),
              onCopy: _exportProfile,
            );
          case ProfilesWorkspaceMode.edit:
            workspaceBody = _ProfilesInfoPanel(
              profile: hasActiveProfile ? activeProfile : null,
              routingMode: routingMode,
              rulesProfile: rulesProfile,
              dnsMode: dnsMode,
              tunnelMode: tunnelMode,
              vpnRuleCount: _rulesForBucket(RuleBucket.vpn)
                  .where((rule) => rule.enabled)
                  .length,
              directRuleCount: _rulesForBucket(RuleBucket.direct)
                  .where((rule) => rule.enabled)
                  .length,
              blockedRuleCount: _rulesForBucket(RuleBucket.blocked)
                  .where((rule) => rule.enabled)
                  .length,
            );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: _ProfilesWorkspaceCard(
                mode: profilesWorkspaceMode,
                onModeChanged: (mode) {
                  setState(() {
                    profilesWorkspaceMode = mode;
                  });
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    workspaceBody
                        .animate(key: ValueKey(profilesWorkspaceMode))
                        .fadeIn(duration: 260.ms)
                        .slideY(
                          begin: 0.035,
                          end: 0,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ],
                ),
              ).animate().fadeIn(duration: 220.ms).slideY(
                    begin: 0.02,
                    end: 0,
                    duration: 260.ms,
                    curve: Curves.easeOutCubic,
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final contentWidth = constraints.maxWidth >= 1180
            ? constraints.maxWidth
            : constraints.maxWidth;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: contentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SettingsSectionCard(
                    icon: Icons.shield_outlined,
                    title: loc(appLanguage, 'Connection'),
                    children: [
                      _SettingsToggleRow(
                        icon: Icons.shield_outlined,
                        title: loc(appLanguage, 'VPN (TUN) Mode'),
                        subtitle: loc(
                          appLanguage,
                          'Protect all applications',
                        ),
                        value: tunEnabled,
                        onChanged: (value) async {
                          if (value) {
                            await _switchTunnelMode(TunnelMode.vpn);
                          } else {
                            await _switchTunnelMode(TunnelMode.proxy);
                          }
                        },
                      ),
                      _SettingsDividerLine(),
                      _SettingsToggleRow(
                        icon: Icons.public_rounded,
                        title: loc(appLanguage, 'Proxy'),
                        subtitle: loc(
                          appLanguage,
                          'Proxy: for selected apps only.',
                        ),
                        value: systemProxyEnabled,
                        onChanged: (value) async {
                          if (value) {
                            await _switchTunnelMode(TunnelMode.proxy);
                          } else {
                            await _switchTunnelMode(TunnelMode.vpn);
                          }
                        },
                      ),
                      _SettingsDividerLine(),
                      _SettingsActionRow(
                        icon: Icons.article_outlined,
                        title: loc(appLanguage, 'Open Logs'),
                        subtitle: loc(
                          appLanguage,
                          'Inspect runtime activity and recent errors',
                        ),
                        onTap: _showLogsDialog,
                      ),
                    ],
                  ).animate().fadeIn(duration: 240.ms).slideY(
                        begin: 0.04,
                        end: 0,
                        duration: 280.ms,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 16),
                  _SettingsSectionCard(
                    icon: Icons.info_outline_rounded,
                    title: loc(appLanguage, 'About Us'),
                    children: [
                      _SettingsActionRow(
                        icon: Icons.info_outline_rounded,
                        title: loc(appLanguage, 'About'),
                        subtitle: 'Troodi VPN • Flutter + Go + Xray',
                        onTap: () => _showMessage(
                          'Troodi VPN • Flutter + Go + Xray',
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 90.ms, duration: 240.ms).slideY(
                        begin: 0.04,
                        end: 0,
                        delay: 90.ms,
                        duration: 280.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ],
              ),
            ),
          ),
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
      _showMessage(tr('Clipboard is empty.'), isError: true);
      return;
    }
    try {
      final imported = _parseProfilesInput(raw);
      await _saveProfiles([...imported, ...profiles]);
      if (mounted) {
        _showMessage(
          imported.length == 1
              ? tr('Profile imported from clipboard.')
              : tr('${imported.length} profiles imported from clipboard.'),
        );
      }
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _showProfileImportDialog() async {
    await _showProfileImportDialogWithMode(_ProfileImportMode.link);
  }

  Future<void> _showManualProfileImportDialog() async {
    await _showProfileImportDialogWithMode(_ProfileImportMode.manual);
  }

  Future<void> _showEditProfileDialog(ServerProfile profile) async {
    final imported = await showDialog<List<ServerProfile>>(
      context: context,
      builder: (context) => _ProfileImportDialog(
        initialMode: _ProfileImportMode.manual,
        showModeSwitcher: false,
        initialProfile: profile,
      ),
    );
    if (imported == null || imported.isEmpty) {
      return;
    }
    final updated = imported.first;
    final nextProfiles = profiles
        .map((item) => item.id == profile.id ? updated : item)
        .toList(growable: false);
    final nextActiveId =
        activeProfileId == profile.id ? updated.id : activeProfileId;
    await _saveConfig(
      _currentConfig().copyWith(
        profiles: nextProfiles,
        activeProfileId: nextActiveId,
      ),
    );
    if (mounted) {
      _showMessage(
        tr('Profile updated.'),
      );
    }
  }

  Future<void> _showProfileImportDialogWithMode(_ProfileImportMode mode) async {
    final imported = await showDialog<List<ServerProfile>>(
      context: context,
      builder: (context) => _ProfileImportDialog(
        initialMode: mode,
        showModeSwitcher: mode == _ProfileImportMode.link,
      ),
    );
    if (imported == null || imported.isEmpty) {
      return;
    }
    await _saveProfiles([...imported, ...profiles]);
    if (mounted) {
      _showMessage(
        imported.length == 1
            ? tr('Profile added.')
            : tr('${imported.length} profiles added.'),
      );
    }
  }

  Future<void> _removeProfile(String profileId) async {
    final nextProfiles =
        profiles.where((profile) => profile.id != profileId).toList();
    await _saveProfiles(nextProfiles);
  }

  Future<void> _showProfileDetailsDialog(ServerProfile profile) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _DialogShell(
        maxWidth: 760,
        child: SingleChildScrollView(
          child: _ProfileDetailsCard(profile: profile, compact: true),
        ),
      ),
    );
  }

  Future<void> _exportProfile(ServerProfile profile) async {
    final payload = profile.rawLink.isNotEmpty
        ? profile.rawLink
        : const JsonEncoder.withIndent('  ')
            .convert(_serverProfileToJson(profile));
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) {
      return;
    }
    _showMessage(
      tr('Profile data copied to clipboard.'),
    );
  }

  Future<void> _importProfilesFromFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'VPN configs',
        extensions: <String>['txt', 'json'],
      );
      final file = await openFile(acceptedTypeGroups: const [typeGroup]);
      if (file == null) {
        return;
      }

      final name = file.name.toLowerCase();
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        _showMessage(
          tr('Selected file is empty.'),
          isError: true,
        );
        return;
      }

      final imported = _parseProfilesFile(name, content);
      await _saveProfiles([...imported, ...profiles]);
      if (!mounted) {
        return;
      }
      _showMessage(
        imported.length == 1
            ? tr(
                'Profile imported from file.',
              )
            : tr(
                '${imported.length} profiles imported from file.',
              ),
      );
    } catch (error) {
      _showMessage(error.toString(), isError: true);
    }
  }

  List<ServerProfile> _parseProfilesFile(String fileName, String content) {
    final trimmed = content.trim();
    if (fileName.endsWith('.txt')) {
      return _parseProfilesInput(trimmed);
    }

    if (fileName.endsWith('.json')) {
      final decoded = jsonDecode(trimmed);

      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map(_serverProfileFromJson)
            .toList();
      }

      if (decoded is Map<String, dynamic>) {
        final profilesJson = decoded['profiles'];
        if (profilesJson is List) {
          return profilesJson
              .whereType<Map<String, dynamic>>()
              .map(_serverProfileFromJson)
              .toList();
        }

        if (decoded.containsKey('protocol') ||
            decoded.containsKey('address') ||
            decoded.containsKey('userId') ||
            decoded.containsKey('rawLink')) {
          return [_serverProfileFromJson(decoded)];
        }
      }

      throw Exception(
        tr(
          'Unsupported JSON file format.',
        ),
      );
    }

    return _parseProfilesInput(trimmed);
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
      _showMessage(tr('Rules pasted from clipboard.'));
    }
  }

  Future<String?> _showPasteRulesDialog() async {
    final controller = TextEditingController();
    final clipboard = await Clipboard.getData('text/plain');
    controller.text = clipboard?.text?.trim() ?? '';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Paste list')),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Supported formats'),
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
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(tr('Apply')),
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
        rulesProfile: RulesProfile.global,
        proxyDomains: const [],
        directDomains: const [],
        blockedDomains: const [],
      ),
    );
  }

  bool _russiaRulesDataReady(RuntimeSnapshot r) {
    // If cached files are already present on disk, use them even when
    // background refresh reports a transient error.
    if (r.russiaRoutingAssetsUpdatedAt.isNotEmpty) {
      return true;
    }
    if (r.routingAssetsStatus == 'error') {
      return false;
    }
    return false;
  }

  Future<bool> _showRussiaRulesFirstDownloadDialog({
    bool cancelRevertsProfileToGlobal = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _RussiaRulesFirstDownloadDialog(
        backend: backend,
        language: appLanguage,
        cancelRevertsProfileToGlobal: cancelRevertsProfileToGlobal,
      ),
    );
    return result ?? false;
  }

  Future<void> _applyRulesProfile(RulesProfile profile) async {
    if (profile == RulesProfile.global) {
      await _saveConfig(
        _currentConfig().copyWith(rulesProfile: profile),
      );
      return;
    }
    final readyBackend = await _ensureBackendReady();
    if (!readyBackend) {
      return;
    }
    var snap = await backend.getState();
    if (!_russiaRulesDataReady(snap.runtime)) {
      final ok = await _showRussiaRulesFirstDownloadDialog();
      if (!ok) {
        if (mounted) {
          await _saveConfig(
            _currentConfig().copyWith(rulesProfile: RulesProfile.global),
          );
        }
        return;
      }
      if (!mounted) {
        return;
      }
      snap = await backend.getState();
      if (!_russiaRulesDataReady(snap.runtime)) {
        if (mounted) {
          _showMessage(
            loc(appLanguage, 'Could not download routing rules.'),
            isError: true,
          );
        }
        return;
      }
    }
    await _saveConfig(
      _currentConfig().copyWith(
        rulesProfile: profile,
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

  String _normalizeRuleValue(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return '';
    }
    final withoutScheme = trimmed.replaceFirst(RegExp(r'^[a-z]+://'), '');
    if (RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}/\d{1,2}$').hasMatch(withoutScheme)) {
      return withoutScheme;
    }
    final slashIndex = withoutScheme.indexOf('/');
    final candidate = slashIndex >= 0
        ? withoutScheme.substring(0, slashIndex)
        : withoutScheme;
    return candidate.trim();
  }

  String? _validateRuleValue(String value) {
    if (value.isEmpty) {
      return tr('Enter a domain, IP, or CIDR rule.');
    }
    final type = _detectRuleType(value);
    if (type == null) {
      return tr('Use a valid domain, wildcard, IP, or CIDR.');
    }
    return null;
  }

  RuleType? _detectRuleType(String value) {
    if (_isValidCidr(value)) {
      return RuleType.cidr;
    }
    if (_isValidIpv4(value)) {
      return RuleType.ip;
    }
    if (value == 'localhost') {
      return RuleType.domain;
    }
    if (value.startsWith('*.') && _isValidDomain(value.substring(2))) {
      return RuleType.wildcard;
    }
    if (_isValidDomain(value)) {
      return RuleType.domain;
    }
    return null;
  }

  bool _isValidDomain(String value) {
    final regex = RegExp(
      r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9][a-z0-9-]{0,62}$',
    );
    return regex.hasMatch(value);
  }

  bool _isValidIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      final parsed = int.tryParse(part);
      if (parsed == null || parsed < 0 || parsed > 255) {
        return false;
      }
    }
    return true;
  }

  bool _isValidCidr(String value) {
    final parts = value.split('/');
    if (parts.length != 2) {
      return false;
    }
    final prefix = int.tryParse(parts[1]);
    if (!_isValidIpv4(parts[0]) ||
        prefix == null ||
        prefix < 0 ||
        prefix > 32) {
      return false;
    }
    return true;
  }

  int _ipv4ToInt(String value) {
    final parts = value.split('.').map(int.parse).toList(growable: false);
    return (parts[0] << 24) + (parts[1] << 16) + (parts[2] << 8) + parts[3];
  }

  bool _cidrContains(String cidr, String ip) {
    if (!_isValidCidr(cidr) || !_isValidIpv4(ip)) {
      return false;
    }
    final parts = cidr.split('/');
    final network = _ipv4ToInt(parts[0]);
    final prefix = int.parse(parts[1]);
    final mask = prefix == 0 ? 0 : 0xFFFFFFFF << (32 - prefix);
    return (network & mask) == (_ipv4ToInt(ip) & mask);
  }

  bool _isPrivateIpValue(String value) {
    if (!_isValidIpv4(value)) {
      return false;
    }

    const privateCidrs = <String>[
      '10.0.0.0/8',
      '172.16.0.0/12',
      '192.168.0.0/16',
      '127.0.0.0/8',
      '169.254.0.0/16',
    ];

    for (final cidr in privateCidrs) {
      if (_cidrContains(cidr, value)) {
        return true;
      }
    }

    return false;
  }

  bool _isLikelyRussianRoute(String value) {
    final normalized = value.toLowerCase();
    if (normalized == 'localhost') {
      return true;
    }
    if (_isValidIpv4(normalized)) {
      return false;
    }
    return normalized.endsWith('.ru') || normalized.endsWith('.xn--p1ai');
  }

  _RuleTestResult _testRule(String raw) {
    final value = _normalizeRuleValue(raw);
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
          destination: tr('Blocked'),
          matchedRule: item,
          accent: const Color(0xFFFF9E8B),
          hasMatch: true,
          typeLabel: _detectRuleType(item)?.name.toUpperCase() ?? 'DOMAIN',
          defaultBehavior: '',
        );
      }
    }

    if (routingMode == RoutingMode.whitelist) {
      for (final item in enabledVpn) {
        if (_ruleMatches(item, value)) {
          return _RuleTestResult(
            input: value,
            destination: tr('Via VPN'),
            matchedRule: item,
            accent: const Color(0xFF6BD7AE),
            hasMatch: true,
            typeLabel: _detectRuleType(item)?.name.toUpperCase() ?? 'DOMAIN',
            defaultBehavior: '',
          );
        }
      }
      return _RuleTestResult(
        input: value,
        destination: tr('Open normally'),
        matchedRule: '',
        accent: const Color(0xFF8EA2FF),
        hasMatch: false,
        typeLabel: '',
        defaultBehavior: tr('Open normally'),
      );
    }

    for (final item in enabledDirect) {
      if (_ruleMatches(item, value)) {
        return _RuleTestResult(
          input: value,
          destination: tr('Open normally'),
          matchedRule: item,
          accent: const Color(0xFF8EA2FF),
          hasMatch: true,
          typeLabel: _detectRuleType(item)?.name.toUpperCase() ?? 'DOMAIN',
          defaultBehavior: '',
        );
      }
    }

    if (rulesProfile == RulesProfile.russia) {
      if (_isPrivateIpValue(value)) {
        return _RuleTestResult(
          input: value,
          destination: tr('Open normally'),
          matchedRule: 'geoip:private',
          accent: const Color(0xFF8EA2FF),
          hasMatch: true,
          typeLabel: 'IP',
          defaultBehavior: '',
        );
      }

      if (_isLikelyRussianRoute(value)) {
        return _RuleTestResult(
          input: value,
          destination: tr('Open normally'),
          matchedRule: 'geosite:ru / geoip:ru',
          accent: const Color(0xFF8EA2FF),
          hasMatch: true,
          typeLabel: _detectRuleType(value)?.name.toUpperCase() ?? 'DOMAIN',
          defaultBehavior: '',
        );
      }

      return _RuleTestResult(
        input: value,
        destination: tr('Via VPN'),
        matchedRule: '',
        accent: const Color(0xFF6BD7AE),
        hasMatch: false,
        typeLabel: '',
        defaultBehavior: tr('Russia Smart default'),
      );
    }

    if (routingMode == RoutingMode.blacklist ||
        routingMode == RoutingMode.global) {
      return _RuleTestResult(
        input: value,
        destination: tr('Via VPN'),
        matchedRule: '',
        accent: const Color(0xFF6BD7AE),
        hasMatch: false,
        typeLabel: '',
        defaultBehavior: tr('Via VPN'),
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
    final normalizedRule = _normalizeRuleValue(rule);
    if (normalizedRule.isEmpty) {
      return false;
    }
    final ruleType = _detectRuleType(normalizedRule);
    if (ruleType == RuleType.cidr) {
      return _cidrContains(normalizedRule, value);
    }
    if (ruleType == RuleType.ip) {
      return normalizedRule == value;
    }
    if (normalizedRule == value) {
      return true;
    }
    if (ruleType == RuleType.wildcard) {
      return value == normalizedRule.substring(2) ||
          value.endsWith('.${normalizedRule.substring(2)}');
    }
    if (ruleType == RuleType.domain) {
      return value.endsWith('.$normalizedRule');
    }
    return false;
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
