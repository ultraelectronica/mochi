import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Editable, persisted server address so a distributed APK can be pointed at
/// the household's host device without rebuilding. Defaults to the build-time
/// `MOCHI_SERVER_URL` dart-define (or localhost).
class ServerConfig {
  ServerConfig._();
  static final ServerConfig instance = ServerConfig._();

  static const String _prefKey = 'mochi_server_url';
  static const String _default = String.fromEnvironment(
    'MOCHI_SERVER_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  String _url = _default;
  bool _loaded = false;

  String get url => _url;

  Future<void> load() async {
    if (_loaded) {
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_prefKey);
    if (saved != null && saved.trim().isNotEmpty) {
      _url = saved.trim();
    }
    _loaded = true;
  }

  Future<void> setUrl(String url) async {
    final String trimmed = url.trim();
    _url = trimmed.isEmpty ? _default : trimmed;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _url);
  }

  Future<void> reset() async {
    _url = _default;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}

class AppConfig {
  static const String appTitle = 'Mochi';

  static String get serverUrl => ServerConfig.instance.url;

  /// Must match server `MOCHI_API_KEY` when the server has auth enabled. Pass via
  /// `--dart-define=MOCHI_API_KEY=...` (same value as in `server/.env`).
  static const String apiKey = String.fromEnvironment(
    'MOCHI_API_KEY',
    defaultValue: '',
  );

  static Uri get serverUri => Uri.parse(serverUrl);

  static Uri apiUri(String path, [Map<String, String>? queryParameters]) {
    final Uri resolved = serverUri.resolve(path);
    return resolved.replace(queryParameters: queryParameters);
  }

  static Uri get webSocketUri {
    final Uri uri = serverUri;
    return uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      path: uri.path.isEmpty ? '/' : uri.path,
    );
  }
}

class MochiPalette {
  static const Color background = Color(0xFFFFFCF4);
  static const Color card = Colors.white;
  static const Color ink = Color(0xFF28324E);
  static const Color cloudBlue = Color(0xFFD8F0FF);
  static const Color sky = Color(0xFF8CCEFF);
  static const Color lightPink = Color(0xFFFFE0EC);
  static const Color yellow = Color(0xFFFFF0B5);
  static const Color mint = Color(0xFFD8F6E6);
  static const Color lavender = Color(0xFFE3DFFF);
  static const Color peach = Color(0xFFFFDDC9);
}

ThemeData buildMochiTheme() {
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: MochiPalette.cloudBlue,
        brightness: Brightness.light,
      ).copyWith(
        primary: MochiPalette.cloudBlue,
        secondary: MochiPalette.lightPink,
        surface: Colors.white,
        onSurface: MochiPalette.ink,
        outline: MochiPalette.ink,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: MochiPalette.background,
    fontFamily: 'Pixelify Sans',
    textTheme: ThemeData.light().textTheme.copyWith(
      headlineMedium: const TextStyle(
        fontSize: 31,
        fontWeight: FontWeight.w700,
        height: 1.05,
        color: MochiPalette.ink,
      ),
      titleLarge: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: MochiPalette.ink,
      ),
      titleMedium: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: MochiPalette.ink,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: MochiPalette.ink.withValues(alpha: 0.9),
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: MochiPalette.ink.withValues(alpha: 0.8),
      ),
      labelLarge: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: MochiPalette.ink,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      indicatorColor: MochiPalette.cloudBlue.withValues(alpha: 0.25),
      iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
        final bool selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected
              ? MochiPalette.ink
              : MochiPalette.ink.withValues(alpha: 0.58),
          size: 22,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((
        Set<WidgetState> states,
      ) {
        final bool selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontFamily: 'Pixelify Sans',
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected
              ? MochiPalette.ink
              : MochiPalette.ink.withValues(alpha: 0.6),
        );
      }),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MochiPalette.cloudBlue,
        foregroundColor: MochiPalette.ink,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(
          fontFamily: 'Pixelify Sans',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: MochiPalette.ink, width: 2.5),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: MochiPalette.ink.withValues(alpha: 0.42)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: MochiPalette.ink, width: 2.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: MochiPalette.ink, width: 3),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: MochiPalette.ink, width: 2.5),
      ),
    ),
  );
}

BoxDecoration pixelCardDecoration(Color accent) {
  return BoxDecoration(
    color: MochiPalette.card.withValues(alpha: 0.94),
    borderRadius: BorderRadius.circular(28),
    border: Border.all(color: MochiPalette.ink, width: 3),
    boxShadow: <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: 0.55),
        offset: const Offset(6, 6),
        blurRadius: 0,
      ),
      const BoxShadow(
        color: Color(0x44FFFFFF),
        offset: Offset(-2, -2),
        blurRadius: 0,
      ),
    ],
  );
}
