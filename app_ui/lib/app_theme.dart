part of 'main.dart';

enum ConnectionStateValue { connected, disconnected }

enum RoutingMode { global, whitelist, blacklist }

enum DnsMode { auto, proxy, direct }

enum ProfileHealth { healthy, testing, offline }

enum AppPage { home, rules, profiles, settings }

enum TunnelMode { vpn, proxy }

enum ProfilesWorkspaceMode { add, export, edit }

enum RuleType { domain, wildcard, ip, cidr }

enum RuleBucket { vpn, direct, blocked }

enum RulesProfile { global, russia }

enum AppLanguage { en, ru, zh }

AppLanguage _activeLanguage = AppLanguage.ru;

extension AppLanguageX on AppLanguage {
  String get label => switch (this) {
        AppLanguage.en => 'English',
        AppLanguage.ru => '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
        AppLanguage.zh => '\u4e2d\u6587',
      };

  String get shortLabel => switch (this) {
        AppLanguage.en => 'EN',
        AppLanguage.ru => 'RU',
        AppLanguage.zh => 'ZH',
      };

  String get flag => shortLabel;

  Color get accent => switch (this) {
        AppLanguage.en => const Color(0xFF7FA8FF),
        AppLanguage.ru => const Color(0xFF7ED2FF),
        AppLanguage.zh => const Color(0xFFFF8F70),
      };
}

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
    return ButtonStyle(
      backgroundColor: WidgetStatePropertyAll(bg),
      foregroundColor: const WidgetStatePropertyAll(Colors.white),
      elevation: const WidgetStatePropertyAll(0),
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ButtonStyle outlinedButton() {
    return ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(AppPalette.text),
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      side: WidgetStatePropertyAll(
        BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static ButtonStyle textButton() {
    return ButtonStyle(
      foregroundColor: const WidgetStatePropertyAll(AppPalette.text),
      mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.click),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
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
      padding: const EdgeInsets.all(38),
      disabledForegroundColor: const Color(0xFF9AA0AE).withValues(alpha: 0.7),
    );
  }
}
