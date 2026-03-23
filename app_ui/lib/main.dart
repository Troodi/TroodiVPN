import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'lang/translations.dart';

part 'app_theme.dart';
part 'app_localizations.dart';
part 'app_models.dart';
part 'backend.dart';
part 'dashboard_screen.dart';
part 'dashboard_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _appendFrontendHeartbeat('main() entered');
  await _installFrontendCrashLogging();
  _appendFrontendHeartbeat('crash logging installed');
  runZonedGuarded(
    () => runApp(const TroodiVpnApp()),
    (error, stackTrace) {
      _appendFrontendCrashLog('ZONE', error, stackTrace);
    },
  );
}

Future<void> _installFrontendCrashLogging() async {
  FlutterError.onError = (details) {
    _appendFrontendCrashLog(
      'FLUTTER',
      details.exception,
      details.stack ?? StackTrace.current,
    );
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    _appendFrontendCrashLog('PLATFORM', error, stackTrace);
    return false;
  };
}

void _appendFrontendCrashLog(String source, Object error, StackTrace stackTrace) {
  final now = DateTime.now().toIso8601String();
  final payload = StringBuffer()
    ..writeln('[$now] source=$source')
    ..writeln('error=$error')
    ..writeln(stackTrace.toString())
    ..writeln('---');
  for (final path in _frontendLogPaths()) {
    try {
      final logFile = File(path);
      logFile.parent.createSync(recursive: true);
      logFile.writeAsStringSync(
        payload.toString(),
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Continue with other paths.
    }
  }
  stderr.writeln(payload.toString());
}

void _appendFrontendHeartbeat(String message) {
  final now = DateTime.now().toIso8601String();
  final payload = '[$now] heartbeat=$message\n';
  for (final path in _frontendLogPaths()) {
    try {
      final logFile = File(path);
      logFile.parent.createSync(recursive: true);
      logFile.writeAsStringSync(payload, mode: FileMode.append, flush: true);
    } catch (_) {
      // Continue with other paths.
    }
  }
}

List<String> _frontendLogPaths() {
  final home = Platform.environment['HOME'] ?? '';
  return <String>[
    '/tmp/troodi-vpn-frontend-crash.log',
    if (home.isNotEmpty) '$home/.cache/troodi-vpn/frontend-crash.log',
    if (home.isNotEmpty) '$home/troodi-vpn-frontend-crash.log',
  ];
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
        textButtonTheme: TextButtonThemeData(
          style: AppUi.textButton(),
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
