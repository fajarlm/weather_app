import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../models/weather_model.dart';
import 'package:http/http.dart' as http;

class WeatherService {
  static const BASE_URL = 'https://api.openweathermap.org/data/2.5/weather';
  static const FORECAST_URL = 'https://api.openweathermap.org/data/2.5/forecast';
  static const AIR_POLLUTION_URL = 'https://api.openweathermap.org/data/2.5/air_pollution';
  final String apiKey;

  WeatherService(this.apiKey);

  // Menerjemahkan kode negara 2-huruf ke nama lengkap Bahasa Indonesia
  String getFullCountryName(String code) {
    final map = {
      'ID': 'Indonesia',
      'SG': 'Singapura',
      'MY': 'Malaysia',
      'TH': 'Thailand',
      'PH': 'Filipina',
      'JP': 'Jepang',
      'KR': 'Korea Selatan',
      'CN': 'Tiongkok',
      'US': 'Amerika Serikat',
      'GB': 'Inggris',
      'FR': 'Prancis',
      'DE': 'Jerman',
      'IT': 'Italia',
      'RU': 'Rusia',
      'AU': 'Australia',
      'IN': 'India',
      'SA': 'Arab Saudi',
      'AE': 'Uni Emirat Arab',
      'NZ': 'Selandia Baru',
      'CA': 'Kanada',
      'BR': 'Brasil',
      'NL': 'Belanda',
      'ES': 'Spanyol',
      'TR': 'Turki',
      'EG': 'Mesir',
      'ZA': 'Afrika Selatan',
    };
    return map[code.toUpperCase()] ?? code;
  }

  // Mengambil informasi Provinsi dan Negara berdasarkan koordinat
  Future<Map<String, String>> getRegionInfo(double lat, double lon) async {
    String province = '';
    String country = '';

    // 1. Coba menggunakan Geocoding Native bawaan perangkat (hanya berjalan di Android/iOS)
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lon);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        province = place.administrativeArea ?? '';
        country = place.country ?? '';
      }
    } catch (e) {
      debugPrint('Failed to native reverse geocode: $e');
    }

    // 2. Jika native gagal atau mengembalikan data kosong, gunakan OpenWeather Geocoding API sebagai fallback (berjalan di semua platform termasuk Windows)
    if (province.isEmpty || country.isEmpty) {
      try {
        final response = await http.get(
          Uri.parse('https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey'),
        );
        if (response.statusCode == 200) {
          final List data = jsonDecode(response.body);
          if (data.isNotEmpty) {
            final first = data.first;
            if (province.isEmpty) {
              province = first['state'] ?? '';
            }
            if (country.isEmpty) {
              final countryCode = first['country'] ?? '';
              country = getFullCountryName(countryCode);
            }
          }
        }
      } catch (e) {
        debugPrint('Failed to fallback to OpenWeather Geo API: $e');
      }
    }

    return {
      'province': province,
      'country': country,
    };
  }

  // Get current weather and AQI by city name
  Future<Weather> getWeather(String cityName) async {
    final weatherResponse = await http.get(
      Uri.parse('$BASE_URL?q=${Uri.encodeComponent(cityName)}&appid=$apiKey&units=metric'),
    );

    if (weatherResponse.statusCode == 200) {
      final weatherJson = jsonDecode(weatherResponse.body);
      final lat = (weatherJson['coord']['lat'] as num).toDouble();
      final lon = (weatherJson['coord']['lon'] as num).toDouble();

      // Fetch AQI and Region Info
      int aqi = 1;
      String province = '';
      String country = '';

      try {
        final aqiResponse = await http.get(
          Uri.parse('$AIR_POLLUTION_URL?lat=$lat&lon=$lon&appid=$apiKey'),
        );
        if (aqiResponse.statusCode == 200) {
          final aqiJson = jsonDecode(aqiResponse.body);
          aqi = aqiJson['list'][0]['main']['aqi'] as int;
        }
      } catch (e) {
        debugPrint('Failed to load AQI for city: $e');
      }

      // Fetch region info via Geocoding
      try {
        final region = await getRegionInfo(lat, lon);
        province = region['province'] ?? '';
        country = region['country'] ?? '';
      } catch (e) {
        debugPrint('Failed to get Geocoding region: $e');
      }

      // Fallback country name if geocoding returns empty
      if (country.isEmpty && weatherJson['sys'] != null && weatherJson['sys']['country'] != null) {
        country = getFullCountryName(weatherJson['sys']['country']);
      }

      return Weather.fromJson(
        weatherJson,
        aqi: aqi,
        province: province,
        country: country,
      );
    } else {
      final errorMsg = jsonDecode(weatherResponse.body)['message'] ?? 'Failed to load weather data';
      throw Exception(errorMsg);
    }
  }

  // Get forecast by city name
  Future<List<ForecastItem>> getForecast(String cityName) async {
    final response = await http.get(
      Uri.parse('$FORECAST_URL?q=${Uri.encodeComponent(cityName)}&appid=$apiKey&units=metric'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['list'];
      return list.map((item) => ForecastItem.fromJson(item)).toList();
    } else {
      final errorMsg = jsonDecode(response.body)['message'] ?? 'Failed to load forecast data';
      throw Exception(errorMsg);
    }
  }

  // Get current weather and AQI by coordinates in parallel
  Future<Weather> getWeatherByCoordinates(double lat, double lon) async {
    final weatherFuture = http.get(
      Uri.parse('$BASE_URL?lat=$lat&lon=$lon&appid=$apiKey&units=metric'),
    );
    final aqiFuture = http.get(
      Uri.parse('$AIR_POLLUTION_URL?lat=$lat&lon=$lon&appid=$apiKey'),
    );
    final regionFuture = getRegionInfo(lat, lon);

    final responses = await Future.wait([weatherFuture, aqiFuture, regionFuture]);
    final weatherResponse = responses[0] as http.Response;
    final aqiResponse = responses[1] as http.Response;
    final region = responses[2] as Map<String, String>;

    if (weatherResponse.statusCode == 200) {
      final weatherJson = jsonDecode(weatherResponse.body);
      int aqi = 1;
      if (aqiResponse.statusCode == 200) {
        try {
          final aqiJson = jsonDecode(aqiResponse.body);
          aqi = aqiJson['list'][0]['main']['aqi'] as int;
        } catch (e) {
          debugPrint('Failed to parse AQI: $e');
        }
      }

      String province = region['province'] ?? '';
      String country = region['country'] ?? '';

      // Fallback country name if geocoding returns empty
      if (country.isEmpty && weatherJson['sys'] != null && weatherJson['sys']['country'] != null) {
        country = getFullCountryName(weatherJson['sys']['country']);
      }

      return Weather.fromJson(
        weatherJson,
        aqi: aqi,
        province: province,
        country: country,
      );
    } else {
      final errorMsg = jsonDecode(weatherResponse.body)['message'] ?? 'Failed to load weather data';
      throw Exception(errorMsg);
    }
  }

  // Get forecast by coordinates
  Future<List<ForecastItem>> getForecastByCoordinates(double lat, double lon) async {
    final response = await http.get(
      Uri.parse('$FORECAST_URL?lat=$lat&lon=$lon&appid=$apiKey&units=metric'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List list = data['list'];
      return list.map((item) => ForecastItem.fromJson(item)).toList();
    } else {
      final errorMsg = jsonDecode(response.body)['message'] ?? 'Failed to load forecast data';
      throw Exception(errorMsg);
    }
  }

  // Check location permission and get current position coordinates
  Future<Position> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    } 

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }
}
