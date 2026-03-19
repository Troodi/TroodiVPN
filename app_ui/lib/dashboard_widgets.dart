part of 'main.dart';

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.language,
    required this.connection,
    required this.isConnecting,
    required this.routingMode,
    required this.dnsMode,
    required this.latencyMs,
    required this.externalIp,
    required this.downloadBps,
    required this.uploadBps,
    required this.hasActiveProfile,
    required this.activeProfileName,
    required this.selectedPage,
    required this.onLanguageChanged,
    required this.onSelect,
  });

  final AppLanguage language;
  final ConnectionStateValue connection;
  final bool isConnecting;
  final RoutingMode routingMode;
  final DnsMode dnsMode;
  final int latencyMs;
  final String externalIp;
  final int downloadBps;
  final int uploadBps;
  final bool hasActiveProfile;
  final String activeProfileName;
  final AppPage selectedPage;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final ValueChanged<AppPage> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = [
      (AppPage.home, loc(language, 'Home'), Icons.home_filled),
      (
        AppPage.profiles,
        loc(language, 'Profiles'),
        Icons.folder_shared_outlined
      ),
      (AppPage.rules, loc(language, 'Rules'), Icons.account_tree_outlined),
      (AppPage.settings, loc(language, 'Settings'), Icons.settings_rounded),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF252946).withValues(alpha: 0.86),
            const Color(0xFF191E37).withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [AppShadows.darkCard],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'windows/runner/resources/troodi_icon_preview.png',
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Troodi VPN',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppPalette.homeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < items.length; index++) ...[
            _NavButton(
              label: items[index].$2,
              icon: items[index].$3,
              selected: items[index].$1 == selectedPage,
              onTap: () => onSelect(items[index].$1),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          _LanguagePicker(
            value: language,
            onChanged: onLanguageChanged,
          ),
          const SizedBox(height: 8),
          _SidebarInfoCard(
            title: loc(language, 'Connection info'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isConnecting
                          ? Icons.sync_rounded
                          : connection == ConnectionStateValue.connected
                              ? Icons.check_circle_rounded
                              : Icons.pause_circle_filled_rounded,
                      size: 18,
                      color: isConnecting
                          ? const Color(0xFF8EA2FF)
                          : connection == ConnectionStateValue.connected
                              ? const Color(0xFF6CEB86)
                              : const Color(0xFFFFC06A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isConnecting
                          ? loc(language, 'Connecting')
                          : connection == ConnectionStateValue.connected
                              ? loc(language, 'Connected')
                              : loc(language, 'Disconnected'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppPalette.homeText.withValues(alpha: 0.94),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatusRow(
                  label: loc(language, 'Ping'),
                  value: latencyMs > 0 ? '$latencyMs ms' : loc(language, 'n/a'),
                  dark: true,
                ),
                const SizedBox(height: 8),
                _StatusRow(
                  label: 'IP',
                  value: externalIp.isEmpty ? loc(language, 'n/a') : externalIp,
                  dark: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _SidebarInfoCard(
            title: loc(language, 'Network activity'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SidebarTrafficRow(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: const Color(0xFF6CEB86),
                  value: _formatRate(uploadBps),
                ),
                const SizedBox(height: 8),
                _SidebarTrafficRow(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: const Color(0xFFFF9E8B),
                  value: _formatRate(downloadBps),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasActiveProfile
                          ? Icons.folder_open_rounded
                          : Icons.folder_copy_outlined,
                      color: AppPalette.homeText.withValues(alpha: 0.84),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasActiveProfile
                            ? activeProfileName
                            : loc(language, 'No profile selected'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.homeText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  hasActiveProfile
                      ? '${tr('Routing')}: ${routingMode.name} / DNS: ${dnsMode.name.toUpperCase()}'
                      : loc(language,
                          'Open Profiles, import or create a profile, then select it on this screen.'),
                  style: TextStyle(
                    height: 1.45,
                    fontSize: 13,
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

class _SidebarInfoCard extends StatelessWidget {
  const _SidebarInfoCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppPalette.homeText.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          child,
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
        label: tr('Endpoint'),
        value: profile.address.isEmpty
            ? tr('Not configured')
            : '${profile.address}:${profile.port}',
        accent: const Color(0xFF173C4A),
      ),
      _MetricCard(
        label: 'SNI',
        value: profile.sni.isEmpty ? 'Not specified' : profile.sni,
        accent: const Color(0xFF6E5D46),
      ),
      _MetricCard(
        label: tr('Routing'),
        value:
            '${routingMode.name} / ${tunEnabled ? 'TUN' : systemProxyEnabled ? tr('Proxy') : tr('Manual')}',
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
  const _ProfileDetailsCard({
    required this.profile,
    this.compact = false,
  });

  final ServerProfile profile;
  final bool compact;

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

    return Container(
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
        padding: EdgeInsets.all(compact ? 18 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Profile details'),
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: AppPalette.homeText.withValues(alpha: 0.96),
                )),
            const SizedBox(height: 8),
            _StatusRow(label: tr('Name'), value: profile.name),
            const SizedBox(height: 10),
            _StatusRow(
                label: tr('Protocol'), value: profile.protocol.toUpperCase()),
            const SizedBox(height: 10),
            _StatusRow(
              label: tr('Address'),
              value: profile.address.isEmpty
                  ? tr('Not specified')
                  : '${profile.address}:${profile.port}',
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'SNI',
              value: profile.sni.isEmpty ? tr('Not specified') : profile.sni,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: tr('Security'),
              value: profile.security.isEmpty ? tr('Auto') : profile.security,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: tr('Transport'),
              value: profile.transport.isEmpty ? 'tcp' : profile.transport,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'ALPN',
              value: profile.alpn.isEmpty ? tr('Not specified') : profile.alpn,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: tr('Fingerprint'),
              value: profile.fingerprint.isEmpty
                  ? tr('Not specified')
                  : profile.fingerprint,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Flow',
              value: profile.flow.isEmpty ? tr('Not specified') : profile.flow,
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Host / path',
              value:
                  hostPath.isEmpty ? tr('Not specified') : hostPath.join('  '),
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: 'Reality',
              value: reality.isEmpty ? tr('Not specified') : reality.join('  '),
            ),
            const SizedBox(height: 10),
            _StatusRow(
              label: tr('Credential'),
              value: profile.userId.isNotEmpty
                  ? profile.userId
                  : profile.password.isNotEmpty
                      ? profile.password
                      : tr('Not specified'),
            ),
            if (profile.rawLink.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(18),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: SelectableText(
                  profile.rawLink,
                  style: TextStyle(
                    color: AppPalette.homeText.withValues(alpha: 0.9),
                  ),
                ),
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            _CircleGhostIcon(icon: leading, visible: leading != null),
            Expanded(
              child: Align(
                alignment: titleAlign,
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    color: AppPalette.homeText,
                    letterSpacing: -0.6,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 12,
                      ),
                    ],
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

class _ProfilesWorkspaceCard extends StatelessWidget {
  const _ProfilesWorkspaceCard({
    required this.mode,
    required this.onModeChanged,
    required this.child,
  });

  final ProfilesWorkspaceMode mode;
  final ValueChanged<ProfilesWorkspaceMode> onModeChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [AppShadows.darkCard],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProfilesToolbar(
              mode: mode,
              onModeChanged: onModeChanged,
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfilesToolbar extends StatelessWidget {
  const _ProfilesToolbar({
    required this.mode,
    required this.onModeChanged,
  });

  final ProfilesWorkspaceMode mode;
  final ValueChanged<ProfilesWorkspaceMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _ProfilesModePill(
          icon: Icons.travel_explore_rounded,
          label: tr('Add'),
          selected: mode == ProfilesWorkspaceMode.add,
          onTap: () => onModeChanged(ProfilesWorkspaceMode.add),
        ),
        _ProfilesModePill(
          icon: Icons.lock_open_rounded,
          label: tr('Export'),
          selected: mode == ProfilesWorkspaceMode.export,
          onTap: () => onModeChanged(ProfilesWorkspaceMode.export),
        ),
        _ProfilesModePill(
          icon: Icons.info_outline_rounded,
          label: tr('Profile info'),
          selected: mode == ProfilesWorkspaceMode.edit,
          onTap: () => onModeChanged(ProfilesWorkspaceMode.edit),
        ),
      ],
    );
  }
}

class _ProfilesModePill extends StatelessWidget {
  const _ProfilesModePill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [
                      AppPalette.homeAccent,
                      AppPalette.homeAccentStrong,
                    ],
                  )
                : null,
            color: selected ? null : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: AppPalette.homeText.withValues(alpha: 0.92),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: AppPalette.homeText.withValues(alpha: 0.96),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  const _ProfileActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.onPressed,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final VoidCallback onPressed;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.08),
            Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [AppShadows.darkCard],
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [
                  AppPalette.homeAccent,
                  AppPalette.homeAccentStrong,
                ],
              ),
              boxShadow: [AppShadows.glow(AppPalette.homeAccent)],
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.86),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const Spacer(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: _DialogPrimaryButton(
              label: primaryLabel,
              onPressed: onPressed,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 14),
            Text(
              footer!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.72),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfilesSectionHeader extends StatelessWidget {
  const _ProfilesSectionHeader({
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 920;
    if (isCompact || trailing == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(height: 12),
            trailing!,
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 16),
        trailing!,
      ],
    );
  }
}

class _ProfileRowCard extends StatelessWidget {
  const _ProfileRowCard({
    required this.profile,
    required this.isActive,
    required this.onUse,
    required this.onDetails,
    required this.onDelete,
  });

  final ServerProfile profile;
  final bool isActive;
  final VoidCallback onUse;
  final VoidCallback onDetails;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isActive
                ? AppPalette.homeAccent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            isActive
                ? AppPalette.homeAccentStrong.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? AppPalette.homeAccent.withValues(alpha: 0.42)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;

          Widget infoBlock() {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _guessFlagFromName('${profile.name} ${profile.address}'),
                      style: const TextStyle(fontSize: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        profile.name,
                        style: TextStyle(
                          color: AppPalette.homeText.withValues(alpha: 0.96),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${profile.protocol.toUpperCase()} • ${profile.address.isEmpty ? tr('no endpoint') : '${profile.address}:${profile.port}'}',
                  style: TextStyle(
                    color: AppPalette.homeTextMuted.withValues(alpha: 0.88),
                    fontSize: 14,
                  ),
                ),
                if (profile.transport.isNotEmpty ||
                    profile.security.isNotEmpty ||
                    profile.sni.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (profile.transport.isNotEmpty) profile.transport,
                      if (profile.security.isNotEmpty) profile.security,
                      if (profile.sni.isNotEmpty) 'SNI ${profile.sni}',
                    ].join(' • '),
                    style: TextStyle(
                      color: AppPalette.homeTextMuted.withValues(alpha: 0.66),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            );
          }

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniActionButton(
                label: tr('Edit'),
                icon: Icons.edit_outlined,
                primary: true,
                onPressed: onDetails,
              ),
              _MiniActionButton(
                label: isActive ? tr('Selected') : tr('Use'),
                icon: Icons.check_circle_outline_rounded,
                success: isActive,
                onPressed: onUse,
              ),
              _MiniActionButton(
                label: tr('Delete'),
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onPressed: onDelete,
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoBlock(),
                const SizedBox(height: 14),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: infoBlock()),
              const SizedBox(width: 16),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.destructive = false,
    this.success = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool destructive;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final bg = destructive
        ? const Color(0xFF7A3846).withValues(alpha: 0.85)
        : success
            ? const Color(0xFF2F7A56).withValues(alpha: 0.88)
            : primary
                ? AppPalette.homeAccent.withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.08);
    final border = destructive
        ? const Color(0xFFFF9E8B).withValues(alpha: 0.20)
        : success
            ? const Color(0xFF84E0AE).withValues(alpha: 0.24)
            : primary
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.08);
    final fg = destructive
        ? const Color(0xFFFFB7A8)
        : success
            ? const Color(0xFFE5FFF1)
            : AppPalette.homeText.withValues(alpha: 0.94);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: border),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ProfilesExportPanel extends StatelessWidget {
  const _ProfilesExportPanel({
    required this.profiles,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCopy,
  });

  final List<ServerProfile> profiles;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ServerProfile> onCopy;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return _HintCard(
        title: tr('No profiles to export'),
        description: tr(
            'Add or select profiles first, then copy a link or JSON for any of them.'),
        icon: Icons.file_download_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfilesSectionHeader(
          title: tr('Export profiles'),
          trailing: SizedBox(
            width: 320,
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: tr('Search by profile, host or protocol'),
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Column(
          children: [
            for (final profile in profiles) ...[
              _ProfileExportRow(
                profile: profile,
                onCopy: () => onCopy(profile),
              ),
              if (profile != profiles.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProfileExportRow extends StatelessWidget {
  const _ProfileExportRow({
    required this.profile,
    required this.onCopy,
  });

  final ServerProfile profile;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final preview = profile.rawLink.isNotEmpty
        ? profile.rawLink
        : const JsonEncoder.withIndent('  ')
            .convert(_serverProfileToJson(profile));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _guessFlagFromName('${profile.name} ${profile.address}'),
                style: const TextStyle(fontSize: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.96),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile.protocol.toUpperCase()} • ${profile.address.isEmpty ? tr('no endpoint') : '${profile.address}:${profile.port}'}',
                      style: TextStyle(
                        color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 210,
                child: _DialogPrimaryButton(
                  label: tr('Copy profile'),
                  onPressed: onCopy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SelectableText(
            preview,
            maxLines: 3,
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfilesInfoPanel extends StatelessWidget {
  const _ProfilesInfoPanel({
    required this.profile,
    required this.routingMode,
    required this.rulesProfile,
    required this.dnsMode,
    required this.tunnelMode,
    required this.vpnRuleCount,
    required this.directRuleCount,
    required this.blockedRuleCount,
  });

  final ServerProfile? profile;
  final RoutingMode routingMode;
  final RulesProfile rulesProfile;
  final DnsMode dnsMode;
  final TunnelMode tunnelMode;
  final int vpnRuleCount;
  final int directRuleCount;
  final int blockedRuleCount;

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return _HintCard(
        title: tr('No selected profile'),
        description:
            tr('Select a profile first to see the current connection summary.'),
        icon: Icons.info_outline_rounded,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProfilesSectionHeader(
          title: tr('Current profile'),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _guessFlagFromName('${profile!.name} ${profile!.address}'),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile!.name,
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.96),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _InfoStatChip(
                          label: tr('Protocol'),
                          value: profile!.protocol.toUpperCase(),
                        ),
                        _InfoStatChip(
                          label: tr('Address'),
                          value: profile!.address.isEmpty
                              ? tr('not set')
                              : '${profile!.address}:${profile!.port}',
                        ),
                        _InfoStatChip(
                          label: 'SNI',
                          value: profile!.sni.isEmpty
                              ? tr('not set')
                              : profile!.sni,
                        ),
                        _InfoStatChip(
                          label: tr('Security'),
                          value: profile!.security.isEmpty
                              ? tr('not set')
                              : profile!.security,
                        ),
                        _InfoStatChip(
                          label: tr('Mode'),
                          value: tunnelMode == TunnelMode.vpn
                              ? tr('VPN (TUN)')
                              : tr('Proxy'),
                        ),
                        _InfoStatChip(
                          label: tr('Routing'),
                          value: switch (routingMode) {
                            RoutingMode.global => tr('Protect all traffic'),
                            RoutingMode.whitelist => tr('Only selected sites'),
                            RoutingMode.blacklist => tr('Exclude sites'),
                          },
                        ),
                        _InfoStatChip(
                          label: tr('Profile'),
                          value: rulesProfile == RulesProfile.russia
                              ? 'Russia'
                              : 'Global',
                        ),
                        _InfoStatChip(
                          label: 'DNS',
                          value: switch (dnsMode) {
                            DnsMode.auto => 'AUTO',
                            DnsMode.proxy => 'PROXY',
                            DnsMode.direct => 'DIRECT',
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('Routing summary'),
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.94),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoStatChip(
                                label: tr('Via VPN'),
                                value: '$vpnRuleCount',
                              ),
                              _InfoStatChip(
                                label: tr('Open normally'),
                                value: '$directRuleCount',
                              ),
                              _InfoStatChip(
                                label: tr('Blocked'),
                                value: '$blockedRuleCount',
                              ),
                            ],
                          ),
                          if (profile!.transport.isNotEmpty ||
                              profile!.host.isNotEmpty ||
                              profile!.path.isNotEmpty ||
                              profile!.alpn.isNotEmpty ||
                              profile!.fingerprint.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              [
                                if (profile!.transport.isNotEmpty)
                                  '${tr('Transport')}: ${profile!.transport}',
                                if (profile!.host.isNotEmpty)
                                  'Host: ${profile!.host}',
                                if (profile!.path.isNotEmpty)
                                  'Path: ${profile!.path}',
                                if (profile!.alpn.isNotEmpty)
                                  'ALPN: ${profile!.alpn}',
                                if (profile!.fingerprint.isNotEmpty)
                                  'uTLS: ${profile!.fingerprint}',
                              ].join(' / '),
                              style: TextStyle(
                                color: AppPalette.homeTextMuted
                                    .withValues(alpha: 0.82),
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoStatChip extends StatelessWidget {
  const _InfoStatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
            fontSize: 13,
          ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: TextStyle(
                color: AppPalette.homeText.withValues(alpha: 0.94),
                fontWeight: FontWeight.w700,
              ),
            ),
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
      width: 54,
      height: 54,
      child: visible
          ? Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: AppPalette.homeText.withValues(alpha: 0.9),
                size: 28,
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
    required this.isConnecting,
    required this.canConnect,
    required this.isBusy,
    required this.onToggleConnection,
    required this.profileItems,
    required this.selectedProfileId,
    required this.onProfileChanged,
    required this.tunnelMode,
    required this.onTunnelModeChanged,
  });

  final String profileName;
  final ConnectionStateValue connection;
  final bool isConnecting;
  final bool canConnect;
  final bool isBusy;
  final Future<void> Function() onToggleConnection;
  final List<ServerProfile> profileItems;
  final String? selectedProfileId;
  final ValueChanged<String?> onProfileChanged;
  final TunnelMode tunnelMode;
  final ValueChanged<TunnelMode> onTunnelModeChanged;

  @override
  Widget build(BuildContext context) {
    final connected = connection == ConnectionStateValue.connected;
    final statusLabel = isConnecting
        ? tr('CONNECTING')
        : connected
            ? tr('CONNECTED')
            : tr('DISCONNECTED');
    final statusColor = isConnecting
        ? const Color(0xFF8FA4FF)
        : connected
            ? AppPalette.homeAccent
            : const Color(0xFF8D95B2);
    final isCompact = MediaQuery.of(context).size.width < 760;
    final bottomCardWidth = isCompact ? double.infinity : 630.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              statusLabel,
              style: TextStyle(
                letterSpacing: isCompact ? 2.1 : 3.0,
                fontWeight: FontWeight.w300,
                fontSize: isCompact ? 24 : 34,
                color: AppPalette.homeTextMuted.withValues(alpha: 0.88),
              ),
            ),
          ).animate(delay: 120.ms).fadeIn(duration: 240.ms),
          SizedBox(height: isCompact ? 14 : 18),
          Center(
            child: Container(
              width: isCompact ? 144 : 156,
              height: isCompact ? 144 : 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.98),
                    const Color(0xFFD7DEF3).withValues(alpha: 0.92),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                boxShadow: [
                  AppShadows.glow(statusColor),
                ],
              ),
              child: MouseRegion(
                cursor: canConnect && !isBusy
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: IconButton(
                  onPressed: canConnect && !isBusy ? onToggleConnection : null,
                  iconSize: isCompact ? 46 : 52,
                  mouseCursor: canConnect && !isBusy
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic,
                  style: AppUi.powerButton(statusColor),
                  icon: const Icon(Icons.power_settings_new_rounded),
                ),
              ),
            ),
          )
              .animate(delay: 160.ms)
              .fadeIn(duration: 280.ms)
              .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),
          SizedBox(height: isCompact ? 24 : 28),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: bottomCardWidth),
              child: _ServerSelectCard(
                selectedName:
                    profileItems.isEmpty ? tr('No servers yet') : profileName,
                selectedProfileId: selectedProfileId,
                profileItems: profileItems,
                onProfileChanged: onProfileChanged,
              ),
            ),
          )
              .animate(delay: 340.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.04, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 12),
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
                    ? tr('VPN: protects all applications.')
                    : tr('Proxy: for selected apps only.'),
                style: TextStyle(
                  color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
                  fontSize: 13,
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
    required this.selectedName,
    required this.selectedProfileId,
    required this.profileItems,
    required this.onProfileChanged,
  });

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
                            Icons.public_rounded,
                            color: AppPalette.homeAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr('Select VPN Server'),
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
                                  const Icon(
                                    Icons.public_rounded,
                                    size: 22,
                                    color: Color(0xFF73A3FF),
                                  ),
                                  const SizedBox(width: 12),
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
      child: MouseRegion(
        cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: disabled ? null : () => _openServerPicker(context),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
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
                    color: AppPalette.homeAccent.withValues(alpha: 0.18),
                  ),
                  child: const Icon(
                    Icons.public_rounded,
                    color: Color(0xFF73A3FF),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    selectedName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: disabled
                          ? AppPalette.homeTextMuted.withValues(alpha: 0.68)
                          : AppPalette.homeText,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppPalette.homeText.withValues(alpha: 0.72),
                ),
              ],
            ),
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
          height: 56,
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
                  isVpn ? 'VPN' : tr('Proxy'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 52,
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
                  label: tr('Proxy'),
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
                  fontSize: 14,
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

class _RulesModeCard extends StatelessWidget {
  const _RulesModeCard({
    required this.routingMode,
    required this.rulesProfile,
    required this.onModeChanged,
    required this.onProfileChanged,
  });

  final RoutingMode routingMode;
  final RulesProfile rulesProfile;
  final ValueChanged<RoutingMode> onModeChanged;
  final ValueChanged<RulesProfile> onProfileChanged;

  @override
  Widget build(BuildContext context) {
    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('Routing mode'),
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
                  color: AppPalette.homeAccent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  tr('Active mode'),
                  style: TextStyle(
                    color: AppPalette.homeText.withValues(alpha: 0.94),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ModeChoiceChip(
                  label: tr('Protect all traffic'),
                  selected: routingMode == RoutingMode.global,
                  onTap: () => onModeChanged(RoutingMode.global),
                ),
                _ModeChoiceChip(
                  label: tr('Only selected sites'),
                  selected: routingMode == RoutingMode.whitelist,
                  onTap: () => onModeChanged(RoutingMode.whitelist),
                ),
                _ModeChoiceChip(
                  label: tr('Exclude sites'),
                  selected: routingMode == RoutingMode.blacklist,
                  onTap: () => onModeChanged(RoutingMode.blacklist),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _modeExplanation(routingMode),
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            tr('Traffic profile'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.95),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ProfileChoiceChip(
                label: 'Global',
                selected: rulesProfile == RulesProfile.global,
                onTap: () => onProfileChanged(RulesProfile.global),
              ),
              _ProfileChoiceChip(
                label: tr('Russia (Smart)'),
                selected: rulesProfile == RulesProfile.russia,
                onTap: () => onProfileChanged(RulesProfile.russia),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(
              rulesProfile == RulesProfile.russia
                  ? tr(
                      'Russia (Smart): resources blocked in Russia go through VPN, Russian and Russia-only destinations open directly, local/private IPs stay direct, and your manual rules still apply on top.')
                  : tr(
                      'Global profile: only your current mode and manual rules are used, without a regional preset.'),
              style: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileChoiceChip extends StatelessWidget {
  const _ProfileChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        AppPalette.homeAccent.withValues(alpha: 0.42),
                        AppPalette.homeAccentStrong.withValues(alpha: 0.28),
                      ],
                    )
                  : null,
              color: selected ? null : Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected
                    ? AppPalette.homeAccent.withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: AppPalette.homeText.withValues(alpha: 0.95),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RulesVisualizationCard extends StatelessWidget {
  const _RulesVisualizationCard({
    required this.routingMode,
    required this.vpnDomains,
    required this.directDomains,
    required this.blockedDomains,
  });

  final RoutingMode routingMode;
  final List<String> vpnDomains;
  final List<String> directDomains;
  final List<String> blockedDomains;

  @override
  Widget build(BuildContext context) {
    final lines = switch (routingMode) {
      RoutingMode.global => [
          'All traffic → VPN',
          if (directDomains.isNotEmpty)
            'Except: ${directDomains.take(3).join(', ')}',
        ],
      RoutingMode.whitelist => [
          'Only selected sites → VPN',
          if (vpnDomains.isNotEmpty) vpnDomains.take(3).join(', '),
        ],
      RoutingMode.blacklist => [
          'All traffic → VPN',
          if (directDomains.isNotEmpty)
            'Except: ${directDomains.take(3).join(', ')}',
        ],
    };

    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Traffic routing',
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                line,
                style: TextStyle(
                  color: AppPalette.homeText.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (blockedDomains.isNotEmpty)
            Text(
              'Blocked: ${blockedDomains.take(2).join(', ')}',
              style: TextStyle(
                color: const Color(0xFFFFA69A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _RoutingTreeCard extends StatelessWidget {
  const _RoutingTreeCard({
    required this.routingMode,
    required this.vpnDomains,
    required this.directDomains,
  });

  final RoutingMode routingMode;
  final List<String> vpnDomains;
  final List<String> directDomains;

  @override
  Widget build(BuildContext context) {
    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Routing preview'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('Internet'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.92),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '  |\n  v',
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.8),
              height: 1.15,
            ),
          ),
          Text(
            tr('VPN tunnel'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.92),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          if (routingMode == RoutingMode.whitelist) ...[
            for (final item in vpnDomains.take(3))
              _RoutingTreeLine(label: '$item -> ${tr('Via VPN')}'),
            _RoutingTreeLine(
              label: tr('Other traffic → Open normally'),
              faded: true,
            ),
          ] else ...[
            for (final item in directDomains.take(3))
              _RoutingTreeLine(label: '$item -> ${tr('Open normally')}'),
            _RoutingTreeLine(label: tr('Other traffic → VPN')),
          ],
        ],
      ),
    );
  }
}

class _RoutingTreeLine extends StatelessWidget {
  const _RoutingTreeLine({
    required this.label,
    this.faded = false,
  });

  final String label;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '  +-- $label',
        style: TextStyle(
          color: faded
              ? AppPalette.homeTextMuted.withValues(alpha: 0.72)
              : AppPalette.homeText.withValues(alpha: 0.9),
          fontSize: 13,
        ),
      ),
    );
  }
}

class _RuleTesterCard extends StatelessWidget {
  const _RuleTesterCard({
    required this.controller,
    required this.result,
    required this.onChanged,
  });

  final TextEditingController controller;
  final _RuleTestResult result;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Test domain / IP'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  style: TextStyle(
                    color: AppPalette.homeText.withValues(alpha: 0.94),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'example.com',
                    hintStyle: TextStyle(
                      color: AppPalette.homeTextMuted.withValues(alpha: 0.90),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: onChanged,
                child: Text(tr('Test')),
              ),
            ],
          ),
          if (!result.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Result:',
                    style: TextStyle(
                      color: AppPalette.homeText.withValues(alpha: 0.94),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${result.input} -> ${result.destination}',
                    style: TextStyle(
                      color: result.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    result.hasMatch
                        ? '${tr('Matched rule')}: ${result.matchedRule}'
                        : tr('No matching rules'),
                    style: TextStyle(
                      color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesQuickActionsCard extends StatelessWidget {
  const _RulesQuickActionsCard({
    required this.onReset,
    required this.onRestoreRecommended,
  });

  final Future<void> Function() onReset;
  final Future<void> Function() onRestoreRecommended;

  @override
  Widget build(BuildContext context) {
    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Reset rules'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onRestoreRecommended,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Restore recommended rules'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onReset,
    required this.onRestoreRecommended,
  });

  final Future<void> Function() onReset;
  final Future<void> Function() onRestoreRecommended;

  @override
  Widget build(BuildContext context) {
    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Restore a safe starting point or clear all lists and rebuild them from scratch.',
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset rules'),
              ),
              FilledButton.icon(
                onPressed: onRestoreRecommended,
                icon: const Icon(Icons.auto_fix_high_rounded),
                label: const Text('Restore recommended rules'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RulesGlassCard extends StatelessWidget {
  const _RulesGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        child: child,
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({
    required this.child,
    this.maxWidth = 560,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151A30),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [AppShadows.darkCard],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DialogSecondaryButton extends StatelessWidget {
  const _DialogSecondaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppPalette.homeText.withValues(alpha: 0.92),
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _DialogPrimaryButton extends StatelessWidget {
  const _DialogPrimaryButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [
            AppPalette.homeAccent,
            AppPalette.homeAccentStrong,
          ],
        ),
        boxShadow: [
          AppShadows.glow(AppPalette.homeAccentStrong),
        ],
      ),
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RuleConflictsCard extends StatelessWidget {
  const _RuleConflictsCard({required this.conflicts});

  final List<String> conflicts;

  @override
  Widget build(BuildContext context) {
    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rule conflicts',
            style: TextStyle(
              color: const Color(0xFFFFC7BC),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (final item in conflicts.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'вЂў $item',
                style: TextStyle(
                  color: AppPalette.homeText.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeChoiceChip extends StatelessWidget {
  const _ModeChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppPalette.homeAccent.withValues(alpha: 0.22)
                : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppPalette.homeAccent.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RuleTypeBadge extends StatelessWidget {
  const _RuleTypeBadge({required this.rule});

  final String rule;

  @override
  Widget build(BuildContext context) {
    final label = rule.contains('/')
        ? 'CIDR'
        : RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(rule)
            ? 'IP'
            : rule.startsWith('*.')
                ? 'WILDCARD'
                : 'DOMAIN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppPalette.homeTextMuted.withValues(alpha: 0.88),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RuleTestResult {
  const _RuleTestResult({
    required this.input,
    required this.destination,
    required this.matchedRule,
    required this.accent,
    required this.hasMatch,
    required this.typeLabel,
    required this.defaultBehavior,
  });

  const _RuleTestResult.empty()
      : input = '',
        destination = '',
        matchedRule = '',
        accent = Colors.transparent,
        hasMatch = false,
        typeLabel = '',
        defaultBehavior = '';

  final String input;
  final String destination;
  final String matchedRule;
  final Color accent;
  final bool hasMatch;
  final String typeLabel;
  final String defaultBehavior;

  bool get isEmpty => input.isEmpty;
}

String _modeExplanation(RoutingMode mode) {
  switch (mode) {
    case RoutingMode.global:
      return tr(
          'All traffic goes through VPN except sites listed in Open normally.');
    case RoutingMode.whitelist:
      return tr('Only sites listed in Via VPN use the VPN tunnel.');
    case RoutingMode.blacklist:
      return tr('All traffic goes through VPN except selected exclusions.');
  }
}

class _TrafficBehaviorCard extends StatelessWidget {
  const _TrafficBehaviorCard({
    required this.routingMode,
    required this.vpnCount,
    required this.directCount,
    required this.blockedCount,
    required this.onViewDetails,
  });

  final RoutingMode routingMode;
  final int vpnCount;
  final int directCount;
  final int blockedCount;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final stats = _behaviorStats(
      routingMode: routingMode,
      vpnCount: vpnCount,
      directCount: directCount,
      blockedCount: blockedCount,
    );

    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Traffic behavior'),
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.96),
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _behaviorHeadline(routingMode),
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.92),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onViewDetails,
                icon: const Icon(Icons.account_tree_outlined, size: 16),
                label: Text(tr('View details')),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppPalette.homeAccent.withValues(alpha: 0.16),
                  foregroundColor: AppPalette.homeText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(
            color: Colors.white.withValues(alpha: 0.08),
            height: 1,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: stats,
          ),
        ],
      ),
    );
  }
}

class _RoutingDetailsDialog extends StatelessWidget {
  const _RoutingDetailsDialog({
    required this.routingMode,
    required this.vpnRules,
    required this.directRules,
    required this.blockedRules,
  });

  final RoutingMode routingMode;
  final List<RoutingRule> vpnRules;
  final List<RoutingRule> directRules;
  final List<RoutingRule> blockedRules;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF151A30),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [AppShadows.darkCard],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Traffic behavior details'),
                          style: TextStyle(
                            color: AppPalette.homeText.withValues(alpha: 0.96),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _modeExplanation(routingMode),
                          style: TextStyle(
                            color: AppPalette.homeTextMuted
                                .withValues(alpha: 0.84),
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _RoutingDiagram(
                routingMode: routingMode,
                vpnRules: vpnRules,
                directRules: directRules,
                blockedRules: blockedRules,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutingDiagram extends StatelessWidget {
  const _RoutingDiagram({
    required this.routingMode,
    required this.vpnRules,
    required this.directRules,
    required this.blockedRules,
  });

  final RoutingMode routingMode;
  final List<RoutingRule> vpnRules;
  final List<RoutingRule> directRules;
  final List<RoutingRule> blockedRules;

  @override
  Widget build(BuildContext context) {
    final hasBlocked = blockedRules.isNotEmpty;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: hasBlocked ? 430 : 390,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _RoutingLinePainter(hasBlocked: hasBlocked),
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.90),
                child: _RoutingNode(
                  title: tr('Internet'),
                  subtitle: tr('Incoming traffic'),
                  accent: const Color(0xFF7AD4FF),
                  icon: Icons.public_rounded,
                  compact: true,
                ),
              ),
              Align(
                alignment: const Alignment(0, -0.34),
                child: _RoutingNode(
                  title: 'Troodi VPN',
                  subtitle: _modeLabel(routingMode),
                  accent: AppPalette.homeAccent,
                  icon: Icons.hub_rounded,
                ),
              ),
              Positioned(
                left: 0,
                bottom: 8,
                width: hasBlocked ? width * 0.31 : width * 0.42,
                child: _RoutingBranch(
                  title: tr('Open normally'),
                  subtitle: routingMode == RoutingMode.whitelist
                      ? tr('Everything else bypasses VPN')
                      : tr('Selected exclusions bypass VPN'),
                  accent: const Color(0xFF97A8FF),
                  icon: Icons.open_in_browser_rounded,
                  rules: directRules,
                  emptyLabel: routingMode == RoutingMode.whitelist
                      ? tr('All other traffic')
                      : tr('No direct exclusions'),
                ),
              ),
              Positioned(
                left: hasBlocked ? width * 0.345 : width * 0.48,
                bottom: 8,
                width: hasBlocked ? width * 0.31 : width * 0.42,
                child: _RoutingBranch(
                  title: tr('VPN tunnel'),
                  subtitle: routingMode == RoutingMode.whitelist
                      ? tr('Only selected rules use VPN')
                      : tr('All remaining traffic uses VPN'),
                  accent: const Color(0xFF6BD7AE),
                  icon: Icons.shield_rounded,
                  rules: vpnRules,
                  emptyLabel: routingMode == RoutingMode.whitelist
                      ? tr('No selected sites yet')
                      : tr('All remaining traffic'),
                ),
              ),
              if (hasBlocked)
                Positioned(
                  right: 0,
                  bottom: 8,
                  width: width * 0.31,
                  child: _RoutingBranch(
                    title: tr('Blocked'),
                    subtitle: tr('Traffic is dropped'),
                    accent: const Color(0xFFFF9E8B),
                    icon: Icons.block_rounded,
                    rules: blockedRules,
                    emptyLabel: tr('No blocked rules'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RoutingNode extends StatelessWidget {
  const _RoutingNode({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 180 : 230,
        maxWidth: compact ? 220 : 260,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 18,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 34 : 40,
            height: compact ? 34 : 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: compact ? 18 : 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppPalette.homeText.withValues(alpha: 0.96),
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
                    fontSize: compact ? 11 : 12,
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

class _RoutingBranch extends StatelessWidget {
  const _RoutingBranch({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.rules,
    required this.emptyLabel,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final List<RoutingRule> rules;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppPalette.homeText.withValues(alpha: 0.96),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
              height: 1.4,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          rules.isEmpty
              ? Text(
                  emptyLabel,
                  style: TextStyle(
                    color: AppPalette.homeTextMuted.withValues(alpha: 0.72),
                    fontSize: 12,
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _previewRuleChips(rules, accent),
                ),
        ],
      ),
    );
  }
}

class _RoutingLinePainter extends CustomPainter {
  const _RoutingLinePainter({required this.hasBlocked});

  final bool hasBlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final subtle = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final vpn = Paint()
      ..color = const Color(0xFF6BD7AE).withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final direct = Paint()
      ..color = const Color(0xFF97A8FF).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final blocked = Paint()
      ..color = const Color(0xFFFF9E8B).withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final top = Offset(size.width * 0.5, size.height * 0.12);
    final center = Offset(size.width * 0.5, size.height * 0.32);
    final left = Offset(size.width * 0.2, size.height * 0.78);
    final mid = Offset(
      hasBlocked ? size.width * 0.5 : size.width * 0.78,
      size.height * 0.78,
    );

    canvas.drawLine(top, center, subtle);

    final leftPath = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
          size.width * 0.38, size.height * 0.50, left.dx, left.dy);
    canvas.drawPath(leftPath, direct);

    final midPath = Path()
      ..moveTo(center.dx, center.dy)
      ..quadraticBezierTo(
          size.width * 0.54, size.height * 0.50, mid.dx, mid.dy);
    canvas.drawPath(midPath, vpn);

    if (hasBlocked) {
      final right = Offset(size.width * 0.8, size.height * 0.80);
      final rightPath = Path()
        ..moveTo(center.dx, center.dy)
        ..quadraticBezierTo(
          size.width * 0.66,
          size.height * 0.50,
          right.dx,
          right.dy,
        );
      canvas.drawPath(rightPath, blocked);
    }
  }

  @override
  bool shouldRepaint(covariant _RoutingLinePainter oldDelegate) {
    return oldDelegate.hasBlocked != hasBlocked;
  }
}

class _DomainTestCard extends StatelessWidget {
  const _DomainTestCard({
    required this.controller,
    required this.result,
    required this.onChanged,
  });

  final TextEditingController controller;
  final _RuleTestResult result;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return _RulesGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Test domain / IP',
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: (_) => onChanged(),
                  style: TextStyle(
                    color: AppPalette.homeText.withValues(alpha: 0.94),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter domain or IP',
                    hintStyle: TextStyle(
                      color: AppPalette.homeTextMuted.withValues(alpha: 0.90),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onChanged,
                child: Text(tr('Test')),
              ),
            ],
          ),
          if (!result.isEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    result.accent.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.03),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: result.accent.withValues(alpha: 0.26),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.destination,
                    style: TextStyle(
                      color: result.accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InlineInfoChip(
                        label: result.input,
                        accent: result.accent,
                      ),
                      if (result.typeLabel.isNotEmpty)
                        _InlineInfoChip(
                          label: result.typeLabel,
                          accent: result.accent,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ResultRow(
                    label: tr('Matched rule'),
                    value: result.hasMatch
                        ? result.matchedRule
                        : tr('No matching rules'),
                  ),
                  if (!result.hasMatch &&
                      result.defaultBehavior.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _ResultRow(
                      label: tr('Default behavior'),
                      value: result.defaultBehavior,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesColumnCard extends StatelessWidget {
  const _RulesColumnCard({
    required this.title,
    required this.subtitle,
    required this.placeholder,
    required this.accent,
    required this.rules,
    required this.errorText,
    required this.searchController,
    required this.inputController,
    required this.emptyText,
    required this.onChanged,
    required this.onAdd,
    required this.onPaste,
    required this.onToggleRule,
    required this.onDeleteRule,
    required this.onEditRule,
  });

  final String title;
  final String subtitle;
  final String placeholder;
  final Color accent;
  final List<RoutingRule> rules;
  final String? errorText;
  final TextEditingController searchController;
  final TextEditingController inputController;
  final String emptyText;
  final VoidCallback onChanged;
  final Future<void> Function() onAdd;
  final Future<void> Function() onPaste;
  final void Function(String value, bool enabled) onToggleRule;
  final Future<void> Function(String value) onDeleteRule;
  final Future<void> Function(RoutingRule rule) onEditRule;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final filtered = rules
        .where((rule) => rule.value.toLowerCase().contains(query))
        .toList(growable: false);
    return SizedBox(
      height: 710,
      child: _RulesGlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$title (${rules.length})',
                    style: TextStyle(
                      color: AppPalette.homeText.withValues(alpha: 0.96),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${rules.length} rules',
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
            _RuleInputRow(
              controller: inputController,
              placeholder: placeholder,
              accent: accent,
              errorText: errorText,
              onAdd: onAdd,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onPaste,
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.homeText.withValues(alpha: 0.92),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                label: Text(
                  tr('Paste list'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: searchController,
              onChanged: (_) => onChanged(),
              style: TextStyle(
                color: AppPalette.homeText.withValues(alpha: 0.94),
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: tr('Search rules...'),
                hintStyle: TextStyle(
                  color: AppPalette.homeTextMuted.withValues(alpha: 0.90),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr('Supported formats'),
              style: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.78),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FormatChip(label: 'example.com'),
                _FormatChip(label: '*.example.com'),
                _FormatChip(label: '1.1.1.1'),
                _FormatChip(label: '192.168.0.0/24'),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        emptyText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppPalette.homeTextMuted.withValues(
                            alpha: 0.72,
                          ),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final rule = filtered[index];
                        return _RuleListItem(
                          rule: rule,
                          accent: accent,
                          onToggle: (enabled) =>
                              onToggleRule(rule.value, enabled),
                          onDelete: () => onDeleteRule(rule.value),
                          onEdit: () => onEditRule(rule),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleInputRow extends StatelessWidget {
  const _RuleInputRow({
    required this.controller,
    required this.placeholder,
    required this.accent,
    required this.errorText,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String placeholder;
  final Color accent;
  final String? errorText;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onAdd(),
                style: TextStyle(
                  color: AppPalette.homeText.withValues(alpha: 0.94),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: placeholder,
                  hintStyle: TextStyle(
                    color: AppPalette.homeTextMuted.withValues(alpha: 0.90),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add'),
              style: AppUi.primaryButton(accent),
            ),
          ],
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(
              color: Color(0xFFFF9E8B),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _RuleListItem extends StatelessWidget {
  const _RuleListItem({
    required this.rule,
    required this.accent,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    this.isDragPreview = false,
  });

  final RoutingRule rule;
  final Color accent;
  final ValueChanged<bool> onToggle;
  final Future<void> Function() onDelete;
  final Future<void> Function() onEdit;
  final bool isDragPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: rule.enabled
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDragPreview
              ? accent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.08),
        ),
        boxShadow: isDragPreview ? [AppShadows.glow(accent)] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.public_rounded, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: rule.enabled
                        ? AppPalette.homeText.withValues(alpha: 0.95)
                        : AppPalette.homeTextMuted.withValues(alpha: 0.58),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    decoration:
                        rule.enabled ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RuleTypeBadge(rule: rule.value),
                    if (!rule.enabled) const _FormatChip(label: 'Disabled'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isDragPreview)
            Switch(
              value: rule.enabled,
              onChanged: onToggle,
            ),
          if (!isDragPreview)
            IconButton(
              splashRadius: 18,
              tooltip: tr('Delete rule'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: AppPalette.homeTextMuted.withValues(alpha: 0.86),
            ),
          IconButton(
            splashRadius: 18,
            tooltip: tr('Edit rule'),
            onPressed: isDragPreview ? null : onEdit,
            icon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: isDragPreview
                  ? AppPalette.homeTextMuted.withValues(alpha: 0.40)
                  : accent.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditRuleDialog extends StatefulWidget {
  const _EditRuleDialog({
    required this.title,
    required this.initialValue,
    required this.controller,
    required this.normalizeRule,
    required this.validateRule,
  });

  final String title;
  final String initialValue;
  final TextEditingController controller;
  final String Function(String raw) normalizeRule;
  final String? Function(String value) validateRule;

  @override
  State<_EditRuleDialog> createState() => _EditRuleDialogState();
}

class _EditRuleDialogState extends State<_EditRuleDialog> {
  String? errorText;

  void _submit() {
    final normalized = widget.normalizeRule(widget.controller.text);
    final error = widget.validateRule(normalized);
    if (error != null) {
      setState(() {
        errorText = error;
      });
      return;
    }

    Navigator.of(context).pop(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Edit rule in ${widget.title}'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Update the value and save the rule.',
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.94),
            ),
            decoration: InputDecoration(
              hintText: widget.initialValue,
              hintStyle: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.90),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 8),
            Text(
              errorText!,
              style: const TextStyle(
                color: Color(0xFFFF9E8B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _DialogSecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              _DialogPrimaryButton(
                label: 'Save',
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinuxSudoDialog extends StatelessWidget {
  const _LinuxSudoDialog({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Administrator access required'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'VPN (TUN) on Linux needs sudo to start Xray and configure routes. The password is kept only in memory until the app is restarted.',
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: controller,
            obscureText: true,
            autofocus: true,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.94),
            ),
            decoration: InputDecoration(
              labelText: tr('Password'),
              labelStyle: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
            ),
            onSubmitted: (_) => Navigator.of(context).pop(controller.text),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _DialogSecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              _DialogPrimaryButton(
                label: tr('Continue'),
                onPressed: () => Navigator.of(context).pop(controller.text),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasteListDialog extends StatefulWidget {
  const _PasteListDialog({
    required this.bucket,
    required this.title,
    required this.normalizeRule,
    required this.validateRule,
  });

  final RuleBucket bucket;
  final String title;
  final String Function(String raw) normalizeRule;
  final String? Function(String value) validateRule;

  @override
  State<_PasteListDialog> createState() => _PasteListDialogState();
}

class _PasteListDialogState extends State<_PasteListDialog> {
  late final TextEditingController controller;
  List<String> invalidLines = const [];

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = <String>[];
    final invalid = <String>[];

    for (final rawLine in controller.text.split(RegExp(r'[\r\n]+'))) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final normalized = widget.normalizeRule(trimmed);
      final error = widget.validateRule(normalized);
      if (error != null) {
        invalid.add(trimmed);
        continue;
      }
      if (!valid.contains(normalized)) {
        valid.add(normalized);
      }
    }

    if (valid.isEmpty && invalid.isNotEmpty) {
      setState(() {
        invalidLines = invalid;
      });
      return;
    }

    Navigator.of(context).pop(
      _PasteListResult(validRules: valid, invalidLines: invalid),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      maxWidth: 760,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Paste list to ${widget.title}'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'One rule per line. Empty lines are ignored.',
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FormatChip(label: 'example.com'),
              _FormatChip(label: '*.example.com'),
              _FormatChip(label: '1.1.1.1'),
              _FormatChip(label: '192.168.0.0/24'),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            minLines: 8,
            maxLines: 12,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.94),
            ),
            decoration: InputDecoration(
              hintText: 'github.com\n*.openai.com\n1.1.1.1\n192.168.0.0/24',
              hintStyle: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.9),
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          if (invalidLines.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9E8B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFF9E8B).withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'These lines could not be added',
                    style: TextStyle(
                      color: Color(0xFFFFB6A7),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final line in invalidLines.take(6))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        line,
                        style: TextStyle(
                          color: AppPalette.homeText.withValues(alpha: 0.92),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _DialogSecondaryButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 10),
              _DialogPrimaryButton(
                label: 'Apply',
                onPressed: _submit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasteListResult {
  const _PasteListResult({
    required this.validRules,
    required this.invalidLines,
  });

  final List<String> validRules;
  final List<String> invalidLines;
}

class _PasteListSummaryDialog extends StatelessWidget {
  const _PasteListSummaryDialog({
    required this.addedCount,
    required this.invalidLines,
  });

  final int addedCount;
  final List<String> invalidLines;

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      maxWidth: 620,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Paste results'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            addedCount == 1
                ? tr('1 rule added.')
                : tr('$addedCount rules added.'),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('Lines that need review'),
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF9E8B).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFFFF9E8B).withValues(alpha: 0.20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in invalidLines.take(8))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: AppPalette.homeText.withValues(alpha: 0.92),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: _DialogPrimaryButton(
              label: tr('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleInputRowAlias extends StatelessWidget {
  const _RuleInputRowAlias({
    required this.controller,
    required this.placeholder,
    required this.accent,
    required this.errorText,
    required this.onAdd,
  });

  final TextEditingController controller;
  final String placeholder;
  final Color accent;
  final String? errorText;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context) {
    return _RuleInputRow(
      controller: controller,
      placeholder: placeholder,
      accent: accent,
      errorText: errorText,
      onAdd: onAdd,
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppPalette.homeTextMuted.withValues(alpha: 0.84),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InlineInfoChip extends StatelessWidget {
  const _InlineInfoChip({
    required this.label,
    required this.accent,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppPalette.homeText.withValues(alpha: 0.94),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.94),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _modeLabel(RoutingMode mode) {
  switch (mode) {
    case RoutingMode.global:
      return 'Protect all traffic';
    case RoutingMode.whitelist:
      return 'Only selected sites';
    case RoutingMode.blacklist:
      return 'Exclude sites';
  }
}

String _behaviorHeadline(RoutingMode mode) {
  switch (mode) {
    case RoutingMode.global:
      return 'All traffic goes through VPN';
    case RoutingMode.whitelist:
      return 'Only selected sites use VPN';
    case RoutingMode.blacklist:
      return 'All traffic goes through VPN except selected sites';
  }
}

List<Widget> _behaviorStats({
  required RoutingMode routingMode,
  required int vpnCount,
  required int directCount,
  required int blockedCount,
}) {
  switch (routingMode) {
    case RoutingMode.global:
      return [
        _InlineInfoChip(
          label: '$directCount sites open normally',
          accent: const Color(0xFF97A8FF),
        ),
        _InlineInfoChip(
          label: '$blockedCount blocked',
          accent: const Color(0xFFFF9E8B),
        ),
      ];
    case RoutingMode.whitelist:
      return [
        _InlineInfoChip(
          label: '$vpnCount sites via VPN',
          accent: const Color(0xFF6BD7AE),
        ),
        _InlineInfoChip(
          label: '$blockedCount blocked',
          accent: const Color(0xFFFF9E8B),
        ),
      ];
    case RoutingMode.blacklist:
      return [
        _InlineInfoChip(
          label: '$directCount sites open normally',
          accent: const Color(0xFF97A8FF),
        ),
        _InlineInfoChip(
          label: '$blockedCount blocked',
          accent: const Color(0xFFFF9E8B),
        ),
      ];
  }
}

List<Widget> _previewRuleChips(List<RoutingRule> rules, Color accent) {
  final visible = rules.take(5).toList(growable: false);
  final widgets = <Widget>[
    for (final rule in visible)
      _InlineInfoChip(
        label: rule.value,
        accent: accent,
      ),
  ];
  final hiddenCount = rules.length - visible.length;
  if (hiddenCount > 0) {
    widgets.add(
      _InlineInfoChip(
        label: '+$hiddenCount more',
        accent: accent,
      ),
    );
  }
  return widgets;
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

class _LanguageSwitcher extends StatelessWidget {
  const _LanguageSwitcher({
    required this.value,
    required this.onChanged,
  });

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Language'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppPalette.homeText.withValues(alpha: 0.86),
          ),
        ),
        const SizedBox(height: 10),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: DropdownButtonFormField<AppLanguage>(
            initialValue: value,
            isExpanded: true,
            menuMaxHeight: 280,
            borderRadius: BorderRadius.circular(20),
            elevation: 18,
            dropdownColor: const Color(0xFF222846),
            iconEnabledColor: AppPalette.homeTextMuted.withValues(alpha: 0.88),
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.96),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppPalette.homeAccent.withValues(alpha: 0.30),
                ),
              ),
            ),
            selectedItemBuilder: (context) => AppLanguage.values
                .map(
                  (language) => Row(
                    children: [
                      Text(language.flag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          language.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.homeText.withValues(alpha: 0.96),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(growable: false),
            items: AppLanguage.values
                .map(
                  (language) => DropdownMenuItem<AppLanguage>(
                    value: language,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Text(language.flag,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                language.label,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppPalette.homeText
                                      .withValues(alpha: 0.96),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              language.shortLabel,
                              style: TextStyle(
                                color: AppPalette.homeTextMuted
                                    .withValues(alpha: 0.78),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: (language) {
              if (language != null) {
                onChanged(language);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _SidebarTrafficRow extends StatelessWidget {
  const _SidebarTrafficRow({
    required this.icon,
    required this.iconColor,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppPalette.homeText.withValues(alpha: 0.92),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatRate(int bytesPerSecond) {
  if (bytesPerSecond <= 0) {
    return '0 B/s';
  }

  const units = ['B/s', 'KiB/s', 'MiB/s', 'GiB/s'];
  var value = bytesPerSecond.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final digits = value >= 100
      ? 0
      : value >= 10
          ? 1
          : 2;
  return '${value.toStringAsFixed(digits)} ${units[unitIndex]}';
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.18),
                      Colors.white.withValues(alpha: 0.08),
                    ],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            border: Border.all(
              color: selected
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 22,
                color: selected
                    ? AppPalette.homeText
                    : AppPalette.homeTextMuted.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppPalette.homeText
                        : AppPalette.homeTextMuted.withValues(alpha: 0.95),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: selected
                      ? AppPalette.homeText.withValues(alpha: 0.72)
                      : AppPalette.homeTextMuted.withValues(alpha: 0.64)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.dark = true,
  });

  final String label;
  final String value;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                  color: dark
                      ? AppPalette.homeTextMuted.withValues(alpha: 0.88)
                      : Colors.black.withValues(alpha: 0.55),
                ))),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: dark ? AppPalette.homeText : Colors.black,
          ),
        ),
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
        label = tr('Healthy');
      case ProfileHealth.testing:
        color = const Color(0xFF9A6A22);
        label = tr('Testing');
      case ProfileHealth.offline:
        color = const Color(0xFF8B3A3A);
        label = tr('Offline');
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
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppPalette.homeText.withValues(alpha: 0.94),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
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
  const _ProfileImportDialog({
    this.initialMode = _ProfileImportMode.link,
    this.showModeSwitcher = true,
    this.initialProfile,
  });

  final _ProfileImportMode initialMode;
  final bool showModeSwitcher;
  final ServerProfile? initialProfile;

  @override
  State<_ProfileImportDialog> createState() => _ProfileImportDialogState();
}

class _ProfileImportDialogState extends State<_ProfileImportDialog> {
  late _ProfileImportMode mode;
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
  void initState() {
    super.initState();
    mode = widget.initialMode;
    final profile = widget.initialProfile;
    if (profile != null) {
      protocol = profile.protocol.isEmpty ? 'vless' : profile.protocol;
      transport = profile.transport.isEmpty ? 'tcp' : profile.transport;
      security = profile.security.isEmpty ? 'tls' : profile.security;
      linkController.text = profile.rawLink;
      nameController.text = profile.name;
      addressController.text = profile.address;
      if (profile.port > 0) {
        portController.text = '${profile.port}';
      }
      sniController.text = profile.sni;
      if (profile.alpn.isNotEmpty) {
        alpnController.text = profile.alpn;
      }
      if (profile.fingerprint.isNotEmpty) {
        fingerprintController.text = profile.fingerprint;
      }
      flowController.text = profile.flow;
      hostController.text = profile.host;
      pathController.text = profile.path;
      realityPublicKeyController.text = profile.realityPublicKey;
      realityShortIdController.text = profile.realityShortId;
      if (profile.spiderX.isNotEmpty) {
        spiderXController.text = profile.spiderX;
      }
      userIdController.text = profile.userId;
      passwordController.text = profile.password;
    }
  }

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
    return _DialogShell(
      maxWidth: 980,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.initialProfile == null
                  ? tr('Import profile')
                  : tr('Edit profile'),
              style: TextStyle(
                color: AppPalette.homeText.withValues(alpha: 0.96),
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mode == _ProfileImportMode.manual
                  ? tr(
                      'Fill the main connection fields manually, similar to desktop clients.')
                  : tr(
                      'Paste one or several links and import profiles instantly.'),
              style: TextStyle(
                color: AppPalette.homeTextMuted.withValues(alpha: 0.82),
                fontSize: 14,
                height: 1.45,
              ),
            ),
            if (widget.showModeSwitcher) ...[
              const SizedBox(height: 18),
              SegmentedButton<_ProfileImportMode>(
                showSelectedIcon: false,
                style: AppUi.segmentedHeaderButton(),
                segments: [
                  ButtonSegment(
                    value: _ProfileImportMode.link,
                    label: Text(tr('Link')),
                  ),
                  ButtonSegment(
                    value: _ProfileImportMode.manual,
                    label: Text(tr('Manual')),
                  ),
                ],
                selected: {mode},
                onSelectionChanged: (selection) {
                  setState(() {
                    mode = selection.first;
                    errorText = null;
                  });
                },
              ),
            ],
            const SizedBox(height: 18),
            if (mode == _ProfileImportMode.link)
              TextField(
                controller: linkController,
                minLines: 5,
                maxLines: 9,
                style: TextStyle(
                  color: AppPalette.homeText.withValues(alpha: 0.94),
                ),
                decoration: _dialogDecoration(
                  tr('Paste one or several links: vless://..., trojan://..., vmess://...'),
                ).copyWith(
                  helperText: tr(
                      'You can paste multiple links separated by new lines.'),
                ),
              )
            else
              Column(
                children: [
                  _ImportSectionCard(
                    title: tr('Endpoint'),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            initialValue: protocol,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            dropdownColor: const Color(0xFF1C223C),
                            decoration: _dialogDecoration(
                              tr('Protocol'),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'vless',
                                  child: Text('VLESS',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'trojan',
                                  child: Text('Trojan',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'vmess',
                                  child: Text('VMess',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'shadowsocks',
                                  child: Text('Shadowsocks',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
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
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration(
                              tr('Alias / remarks'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: addressController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration(
                              tr('Address'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextField(
                            controller: portController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            keyboardType: TextInputType.number,
                            decoration: _dialogDecoration('Port'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ImportSectionCard(
                    title: tr('Credentials'),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            controller: userIdController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration('UUID / user'),
                          ),
                        ),
                        SizedBox(
                          width: 240,
                          child: TextField(
                            controller: passwordController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration(
                              tr('Password'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: security,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            dropdownColor: const Color(0xFF1C223C),
                            decoration: _dialogDecoration(
                              tr('Security'),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'tls',
                                  child: Text('TLS',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'reality',
                                  child: Text('Reality',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'none',
                                  child: Text('None',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                            ],
                            onChanged: (value) => setState(() {
                              security = value ?? 'tls';
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: flowController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration('Flow'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ImportSectionCard(
                    title: tr('Transport'),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            initialValue: transport,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            dropdownColor: const Color(0xFF1C223C),
                            decoration: _dialogDecoration(
                              tr('Transport protocol'),
                            ),
                            items: [
                              DropdownMenuItem(
                                  value: 'tcp',
                                  child: Text('TCP',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'ws',
                                  child: Text('WebSocket',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'grpc',
                                  child: Text('gRPC',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                              DropdownMenuItem(
                                  value: 'httpupgrade',
                                  child: Text('HTTPUpgrade',
                                      style: TextStyle(
                                          color: AppPalette.homeText))),
                            ],
                            onChanged: (value) => setState(() {
                              transport = value ?? 'tcp';
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: hostController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration(
                              tr('Camouflage host'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: pathController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration('Path / service'),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: sniController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration('SNI'),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: alpnController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration('ALPN'),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: fingerprintController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration('Fingerprint / uTLS'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ImportSectionCard(
                    title: 'Reality',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: 260,
                          child: TextField(
                            controller: realityPublicKeyController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration(
                              tr('Reality public key'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: realityShortIdController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration(
                              tr('Reality short ID'),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: spiderXController,
                            style: TextStyle(
                              color:
                                  AppPalette.homeText.withValues(alpha: 0.96),
                            ),
                            decoration: _dialogDecoration('SpiderX'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (errorText != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C343E).withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFA8A8).withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  errorText!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 148,
                  child: _DialogSecondaryButton(
                    label: tr('Cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 220,
                  child: _DialogPrimaryButton(
                    label: tr('Save'),
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dialogDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.08),
      labelStyle: TextStyle(
        color: AppPalette.homeTextMuted.withValues(alpha: 0.90),
      ),
      hintStyle: TextStyle(
        color: AppPalette.homeTextMuted.withValues(alpha: 0.72),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: AppPalette.homeAccent.withValues(alpha: 0.45),
        ),
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
      id: widget.initialProfile?.id ?? _profileId(name),
      name: name,
      latencyMs: widget.initialProfile?.latencyMs ?? 0,
      health: widget.initialProfile?.health ?? ProfileHealth.healthy,
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
      rawLink: widget.initialProfile?.rawLink ?? '',
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

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({
    required this.value,
    required this.onChanged,
  });

  final AppLanguage value;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Language'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppPalette.homeText.withValues(alpha: 0.86),
          ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: PopupMenuButton<AppLanguage>(
                tooltip: '',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                elevation: 18,
                padding: EdgeInsets.zero,
                color: const Color(0xFF222846),
                constraints: BoxConstraints.tightFor(
                  width: constraints.maxWidth,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                onSelected: onChanged,
                itemBuilder: (context) => AppLanguage.values
                    .map(
                      (language) => PopupMenuItem<AppLanguage>(
                        value: language,
                        padding: EdgeInsets.zero,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              _LanguageFlagIcon(language: language),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  language.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppPalette.homeText
                                        .withValues(alpha: 0.96),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 26,
                                child: Text(
                                  language.shortLabel,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: AppPalette.homeTextMuted
                                        .withValues(alpha: 0.78),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      _LanguageFlagIcon(language: value),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          value.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppPalette.homeText.withValues(alpha: 0.96),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        value.shortLabel,
                        style: TextStyle(
                          color:
                              AppPalette.homeTextMuted.withValues(alpha: 0.78),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppPalette.homeTextMuted.withValues(alpha: 0.88),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _LanguageFlagIcon extends StatelessWidget {
  const _LanguageFlagIcon({
    required this.language,
  });

  final AppLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: switch (language) {
          AppLanguage.en => Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFFF5F7FB)),
                Column(
                  children: List.generate(
                    7,
                    (index) => Expanded(
                      child: Container(
                        color: index.isEven
                            ? const Color(0xFFD85C69)
                            : const Color(0xFFF5F7FB),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 9,
                    height: 8,
                    color: const Color(0xFF3D4D96),
                  ),
                ),
              ],
            ),
          AppLanguage.ru => Column(
              children: const [
                Expanded(child: ColoredBox(color: Color(0xFFF7F8FB))),
                Expanded(child: ColoredBox(color: Color(0xFF4E78DB))),
                Expanded(child: ColoredBox(color: Color(0xFFD85C69))),
              ],
            ),
          AppLanguage.zh => Stack(
              fit: StackFit.expand,
              children: const [
                ColoredBox(color: Color(0xFFD74B43)),
                Positioned(
                  top: 1,
                  left: 2,
                  child: Icon(
                    Icons.star_rounded,
                    size: 8,
                    color: Color(0xFFF6D04D),
                  ),
                ),
              ],
            ),
        },
      ),
    );
  }
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
