import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'weather_service.dart';
import '../models/weather_model.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _serviceChannelId = 'weather_bg_service';
  static const String _alertsChannelId = 'weather_alerts';

  // API Key yang sama dengan halaman utama
  static const String _apiKey = '0edfae63d21c4a2d409af54687c3f7df';

  /// Inisialisasi notifikasi dan background service
  static Future<void> initialize() async {
    // 1. Setup Android & iOS Notification Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        debugPrint('Notification clicked: ${details.payload}');
      },
    );

    // 2. Buat Notification Channels untuk Android
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      // Channel untuk Background Service (Silent / Low Importance)
      const AndroidNotificationChannel serviceChannel = AndroidNotificationChannel(
        _serviceChannelId,
        'Layanan Latar Belakang Cuaca',
        description: 'Menjaga pemantauan cuaca dan lokasi tetap berjalan di latar belakang.',
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

      // Channel untuk Notifikasi Cuaca (High Importance / Pop-up / Sound)
      const AndroidNotificationChannel alertsChannel = AndroidNotificationChannel(
        _alertsChannelId,
        'Pemberitahuan Cuaca',
        description: 'Menampilkan cuaca di pagi, siang, malam, dan saat berpindah lokasi.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await androidImplementation.createNotificationChannel(serviceChannel);
      await androidImplementation.createNotificationChannel(alertsChannel);

      // Request permission untuk Android 13+
      await androidImplementation.requestNotificationsPermission();
    }

    // 3. Konfigurasi Background Service
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: _serviceChannelId,
        initialNotificationTitle: 'Layanan Cuaca Aktif',
        initialNotificationContent: 'Memantau cuaca dan lokasi Anda...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  /// Entry point untuk iOS Background
  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    return true;
  }

  /// Entry point utama untuk Background Service
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    final FlutterLocalNotificationsPlugin backgroundNotifPlugin =
        FlutterLocalNotificationsPlugin();

    final WeatherService weatherService = WeatherService(_apiKey);

    debugPrint("Background Service Started");

    // Inisialisasi ulang setting notifikasi di isolate background
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await backgroundNotifPlugin.initialize(settings: initializationSettings);

    // Kirim event agar UI tau service sedang berjalan
    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // 1. Memulai pemantauan lokasi menggunakan Geolocation stream
    try {
      final LocationSettings locationSettings = AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 2000, // Trigger event setiap berpindah 2 km (lumayan jauh)
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationText: "Memantau lokasi Anda untuk pembaruan cuaca...",
          notificationTitle: "Pencari Cuaca Aktif",
          enableWakeLock: true,
        ),
      );

      Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position position) async {
        debugPrint("Location change detected in BG: ${position.latitude}, ${position.longitude}");
        
        // Cek perpindahan lokasi yang signifikan
        await _handleLocationChange(position, weatherService, backgroundNotifPlugin);
      });
    } catch (e) {
      debugPrint("Error setting up position stream in background: $e");
    }

    // 2. Timer periodik (setiap 15 menit) untuk memeriksa jadwal pagi, siang, malam
    Timer.periodic(const Duration(minutes: 15), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 15),
          ),
        );
        await _checkScheduledTime(position, weatherService, backgroundNotifPlugin);
      } catch (e) {
        debugPrint("Error checking scheduled weather: $e");
      }
    });

    // Pengecekan awal saat service baru dinyalakan
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );
      await _checkScheduledTime(position, weatherService, backgroundNotifPlugin);
    } catch (_) {}
  }

  /// Menangani perubahan lokasi (jika perpindahan lokasi lumayan jauh)
  static Future<void> _handleLocationChange(
    Position position,
    WeatherService weatherService,
    FlutterLocalNotificationsPlugin notifPlugin,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final double? lastLat = prefs.getDouble('last_notified_lat');
    final double? lastLon = prefs.getDouble('last_notified_lon');

    if (lastLat != null && lastLon != null) {
      final double distance = Geolocator.distanceBetween(
        lastLat,
        lastLon,
        position.latitude,
        position.longitude,
      );

      debugPrint("Distance moved since last notification: ${distance.toStringAsFixed(1)} meters");

      // Jika bergerak lebih dari 2000 meter (2 km)
      if (distance >= 2000) {
        await _showWeatherNotification(
          weatherService,
          position.latitude,
          position.longitude,
          "Lokasi Berubah 📍",
          "Cuaca di tempat baru Anda",
          notifPlugin,
        );
        // Simpan lokasi baru
        await prefs.setDouble('last_notified_lat', position.latitude);
        await prefs.setDouble('last_notified_lon', position.longitude);
      }
    } else {
      // Simpan lokasi pertama kali
      await prefs.setDouble('last_notified_lat', position.latitude);
      await prefs.setDouble('last_notified_lon', position.longitude);
    }
  }

  /// Menangani pengecekan pagi, siang, dan malam hari
  static Future<void> _checkScheduledTime(
    Position position,
    WeatherService weatherService,
    FlutterLocalNotificationsPlugin notifPlugin,
  ) async {
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final todayStr = "${now.year}-${now.month}-${now.day}";

    debugPrint("Checking schedule at: ${now.hour}:${now.minute}");

    // Pagi: 06:00 - 08:00
    if (now.hour >= 6 && now.hour < 8) {
      final lastPagi = prefs.getString('last_notif_pagi') ?? '';
      if (lastPagi != todayStr) {
        await _showWeatherNotification(
          weatherService,
          position.latitude,
          position.longitude,
          "Laporan Cuaca Pagi ☀️",
          "Selamat pagi! Awali hari Anda dengan info cuaca berikut:",
          notifPlugin,
        );
        await prefs.setString('last_notif_pagi', todayStr);
      }
    }

    // Siang: 12:00 - 14:00
    if (now.hour >= 12 && now.hour < 14) {
      final lastSiang = prefs.getString('last_notif_siang') ?? '';
      if (lastSiang != todayStr) {
        await _showWeatherNotification(
          weatherService,
          position.latitude,
          position.longitude,
          "Laporan Cuaca Siang ⛅",
          "Selamat siang! Berikut kondisi cuaca saat ini:",
          notifPlugin,
        );
        await prefs.setString('last_notif_siang', todayStr);
      }
    }

    // Malam: 18:00 - 20:00
    if (now.hour >= 18 && now.hour < 20) {
      final lastMalam = prefs.getString('last_notif_malam') ?? '';
      if (lastMalam != todayStr) {
        await _showWeatherNotification(
          weatherService,
          position.latitude,
          position.longitude,
          "Laporan Cuaca Malam 🌙",
          "Selamat malam! Berikut info cuaca malam ini:",
          notifPlugin,
        );
        await prefs.setString('last_notif_malam', todayStr);
      }
    }
  }

  /// Mengambil data cuaca dan menampilkan notifikasi popup
  static Future<void> _showWeatherNotification(
    WeatherService weatherService,
    double lat,
    double lon,
    String title,
    String greeting,
    FlutterLocalNotificationsPlugin notifPlugin,
  ) async {
    try {
      final Weather weather = await weatherService.getWeatherByCoordinates(lat, lon);

      String condIndo = _getIndonesianCondition(weather.mainCondition);
      String emoji = _getWeatherEmoji(weather.mainCondition);
      String aqiLabel = _getAqiLabel(weather.aqi);

      String locName = weather.cityName;
      if (weather.province.isNotEmpty) {
        locName += ", ${weather.province}";
      }

      final String content = 
          "$greeting\n"
          "📍 $locName\n"
          "$emoji $condIndo • 🌡️ ${weather.temperature.toStringAsFixed(1)}°C • 🍃 AQI: $aqiLabel";

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _alertsChannelId,
        'Pemberitahuan Cuaca',
        channelDescription: 'Menampilkan cuaca di pagi, siang, malam, dan saat berpindah lokasi.',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: true,
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iOSDetails,
      );

      final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await notifPlugin.show(
        id: id,
        title: title,
        body: content,
        notificationDetails: details,
      );
      debugPrint("Notification triggered successfully: $title");
    } catch (e) {
      debugPrint("Failed to fetch weather for notification: $e");
    }
  }

  /// Menerjemahkan kondisi cuaca
  static String _getIndonesianCondition(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear': return 'Cerah';
      case 'clouds': return 'Berawan';
      case 'rain': return 'Hujan';
      case 'drizzle': return 'Gerimis';
      case 'thunderstorm': return 'Hujan Badai';
      case 'snow': return 'Bersalju';
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
        return 'Berkabut';
      default: return condition;
    }
  }

  /// Mengambil emoji cuaca
  static String _getWeatherEmoji(String condition) {
    switch (condition.toLowerCase()) {
      case 'clear': return '☀️';
      case 'clouds': return '☁️';
      case 'rain': return '🌧️';
      case 'drizzle': return '🌦️';
      case 'thunderstorm': return '⛈️';
      case 'snow': return '❄️';
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
        return '🌫️';
      default: return '🌤️';
    }
  }

  /// Mengambil kualitas udara
  static String _getAqiLabel(int aqi) {
    switch (aqi) {
      case 1: return 'Sangat Baik';
      case 2: return 'Baik';
      case 3: return 'Sedang';
      case 4: return 'Buruk';
      case 5: return 'Sangat Buruk';
      default: return 'Sedang';
    }
  }
}
