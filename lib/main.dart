import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'config/api_config.dart';
import 'services/theme_service.dart';
import 'services/wallpaper_service.dart';
import 'services/storage_service.dart';
import 'services/attendance_service.dart';
import 'services/schedule_service.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'screens/splash_gate_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Asegurar que la barra superior del celular (batería, hora, internet) NUNCA se oculte en toda la app
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );

  // Inicialización paralela y ultra-rápida de servicios esenciales (0 ms de espera)
  await Future.wait([
    ThemeService.init(),
    WallpaperService.init(),
    ApiConfig.init(),
    StorageService.init(),
    AttendanceService.init(),
    ConnectivityService.init(),
  ]);

  runApp(const MyApp());

  // Servicios secundarios en segundo plano sin bloquear el primer renderizado visual
  ScheduleService.init();
  NotificationService.init();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        ThemeService.themeModeNotifier,
        ThemeService.accentColorNotifier,
        WallpaperService.wallpaperNotifier,
      ]),
      builder: (context, _) {
        final accent = ThemeService.currentAccent;
        final hasWallpaper = WallpaperService.currentWallpaper.hasWallpaper;
        return MaterialApp(
          navigatorKey: StorageService.navigatorKey,
          title: 'IIAP Asistencia',
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: Duration.zero,
          locale: const Locale('es', 'ES'),
          supportedLocales: const [
            Locale('es', 'ES'),
            Locale('es'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: ThemeMode.dark,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: accent.lightPrimary,
            scaffoldBackgroundColor: hasWallpaper
                ? Colors.transparent
                : accent.lightScaffoldBg,
            cardColor: accent.lightCardBg,
            dividerColor: accent.lightCardBorder,
            colorScheme: ColorScheme.fromSeed(
              seedColor: accent.lightPrimary,
              primary: accent.lightPrimary,
              secondary: accent.accentSample,
              surface: accent.lightCardBg,
              onSurface: const Color(0xFF0F172A),
              primaryContainer: accent.lightContainer,
              brightness: Brightness.light,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: accent.lightCardBg,
              indicatorColor: accent.lightContainer,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: hasWallpaper
                  ? Colors.transparent
                  : accent.lightCardBg,
              foregroundColor: accent.lightPrimary,
              elevation: hasWallpaper ? 0 : 0.5,
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: hasWallpaper ? Brightness.light : Brightness.dark,
                statusBarBrightness: hasWallpaper ? Brightness.dark : Brightness.light,
              ),
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: accent.darkPrimary,
            scaffoldBackgroundColor: hasWallpaper
                ? Colors.transparent
                : accent.darkScaffoldBg,
            cardColor: accent.darkCardBg,
            dividerColor: accent.darkCardBorder,
            colorScheme: ColorScheme.dark(
              primary: accent.darkPrimary,
              secondary: accent.accentSample,
              surface: accent.darkCardBg,
              onSurface: Colors.white,
              primaryContainer: accent.darkContainer,
              onPrimary: Colors.black,
              brightness: Brightness.dark,
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: accent.darkCardBg,
              indicatorColor: accent.darkContainer,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: hasWallpaper
                  ? Colors.transparent
                  : accent.darkCardBg,
              foregroundColor: Colors.white,
              elevation: hasWallpaper ? 0 : 0.5,
              systemOverlayStyle: const SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
                statusBarBrightness: Brightness.dark,
              ),
            ),
            useMaterial3: true,
          ),
          builder: (context, child) {
            return WallpaperService.buildBackgroundContainer(
              context: context,
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const SplashGateScreen(),
        );
      },
    );
  }
}
