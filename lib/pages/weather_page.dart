import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/weather_model.dart';
import '../service/weather_service.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  // Gunakan API Key yang sudah terdaftar
  final _weatherService = WeatherService('0edfae63d21c4a2d409af54687c3f7df');
  final _searchController = TextEditingController();

  Weather? _weather;
  List<ForecastItem> _forecast = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isHourlyForecast = true; // State toggle untuk menampilkan per jam / harian

  @override
  void initState() {
    super.initState();
    _fetchWeatherByCurrentLocation();

    // Redraw search suffixes on typing
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Ambil cuaca berdasarkan GPS saat ini
  Future<void> _fetchWeatherByCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final position = await _weatherService.getCurrentPosition();
      final weather = await _weatherService.getWeatherByCoordinates(
        position.latitude,
        position.longitude,
      );
      final forecast = await _weatherService.getForecastByCoordinates(
        position.latitude,
        position.longitude,
      );

      setState(() {
        _weather = weather;
        _forecast = forecast;
        _isLoading = false;
      });
    } catch (e) {
      // Jika GPS gagal, coba default ke Bogor agar aplikasi tetap menampilkan data
      try {
        final weather = await _weatherService.getWeather('Bogor');
        final forecast = await _weatherService.getForecast('Bogor');
        setState(() {
          _weather = weather;
          _forecast = forecast;
          _isLoading = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Gagal mengakses GPS. Default ke Bogor: ${e.toString().replaceFirst('Exception: ', '')}',
              ),
              backgroundColor: Colors.amber.shade800,
            ),
          );
        }
      } catch (defaultError) {
        setState(() {
          _errorMessage =
              'Gagal memuat cuaca: ${e.toString().replaceFirst('Exception: ', '')}';
          _isLoading = false;
        });
      }
    }
  }

  // Ambil cuaca berdasarkan pencarian kota
  Future<void> _fetchWeatherByCity(String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final weather = await _weatherService.getWeather(city);
      final forecast = await _weatherService.getForecast(city);

      setState(() {
        _weather = weather;
        _forecast = forecast;
        _isLoading = false;
      });
      // Clear search focus
      FocusScope.of(context).unfocus();
    } catch (e) {
      setState(() {
        _errorMessage =
            'Kota tidak ditemukan: ${e.toString().replaceFirst('Exception: ', '')}';
        _isLoading = false;
      });
    }
  }

  // Dapatkan gradient background dinamis berdasarkan kondisi cuaca & waktu
  List<Color> getBackgroundGradient(String condition, String iconCode) {
    // Malam hari (kode ikon OpenWeatherMap berakhiran 'n')
    if (iconCode.endsWith('n')) {
      return [const Color(0xFF0B192C), const Color(0xFF1E3E62)];
    }

    switch (condition.toLowerCase()) {
      case 'clear':
        return [const Color(0xFFD35400), const Color(0xFFE59866)]; // Rust orange & soft peach gold (nyaman di mata)
      case 'clouds':
        return [const Color(0xFF5B86E5), const Color(0xFF36D1DC)]; // Biru awan lembut
      case 'rain':
      case 'drizzle':
        return [const Color(0xFF2B3A67), const Color(0xFF496A81)]; // Hujan abu-abu dingin
      case 'thunderstorm':
        return [const Color(0xFF0F2027), const Color(0xFF203A43), const Color(0xFF2C5364)]; // Badai gelap
      case 'snow':
        return [const Color(0xFF83a4d4), const Color(0xFFb6fbff)]; // Salju putih biru
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
        return [const Color(0xFF757F9A), const Color(0xFFD7DDE8)]; // Kabut keperakan
      default:
        return [const Color(0xFF2193b0), const Color(0xFF6dd5ed)]; // Default biru cerah
    }
  }

  // Terjemahkan kondisi cuaca OpenWeatherMap ke Bahasa Indonesia
  String getIndonesianCondition(String condition, String description) {
    switch (condition.toLowerCase()) {
      case 'clear':
        return 'Cerah';
      case 'clouds':
        if (description.contains('scattered') || description.contains('few')) {
          return 'Cerah Berawan';
        }
        return 'Berawan';
      case 'rain':
        if (description.contains('light') || description.contains('drizzle')) {
          return 'Gerimis';
        }
        return 'Hujan';
      case 'thunderstorm':
        return 'Hujan Badai';
      case 'drizzle':
        return 'Gerimis';
      case 'snow':
        return 'Bersalju';
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
      case 'sand':
      case 'ash':
      case 'squall':
      case 'tornado':
        return 'Berkabut';
      default:
        return condition;
    }
  }

  // Ambil Tanggal Hari Ini yang terformat dengan Bahasa Indonesia
  String _getFormattedToday() {
    final now = DateTime.now();
    String dayStr;
    switch (now.weekday) {
      case 1: dayStr = 'Senin'; break;
      case 2: dayStr = 'Selasa'; break;
      case 3: dayStr = 'Rabu'; break;
      case 4: dayStr = 'Kamis'; break;
      case 5: dayStr = 'Jumat'; break;
      case 6: dayStr = 'Sabtu'; break;
      case 7: dayStr = 'Minggu'; break;
      default: dayStr = '';
    }

    String monthStr;
    switch (now.month) {
      case 1: monthStr = 'Januari'; break;
      case 2: monthStr = 'Februari'; break;
      case 3: monthStr = 'Maret'; break;
      case 4: monthStr = 'April'; break;
      case 5: monthStr = 'Mei'; break;
      case 6: monthStr = 'Juni'; break;
      case 7: monthStr = 'Juli'; break;
      case 8: monthStr = 'Agustus'; break;
      case 9: monthStr = 'September'; break;
      case 10: monthStr = 'Oktober'; break;
      case 11: monthStr = 'November'; break;
      case 12: monthStr = 'Desember'; break;
      default: monthStr = '';
    }

    return '$dayStr, ${now.day} $monthStr ${now.year}';
  }

  // Format tanggal untuk Prakiraan cuaca (Per Jam)
  String formatDateTime(DateTime dateTime) {
    final hourStr = dateTime.hour.toString().padLeft(2, '0');
    final minuteStr = dateTime.minute.toString().padLeft(2, '0');
    return '$hourStr:$minuteStr';
  }

  // Format tanggal untuk Prakiraan cuaca (Harian)
  String formatToDayOnly(DateTime dateTime) {
    final now = DateTime.now();
    if (dateTime.day == now.day) {
      return 'Hari ini';
    } else if (dateTime.day == now.add(const Duration(days: 1)).day) {
      return 'Besok';
    } else {
      switch (dateTime.weekday) {
        case 1: return 'Senin';
        case 2: return 'Selasa';
        case 3: return 'Rabu';
        case 4: return 'Kamis';
        case 5: return 'Jumat';
        case 6: return 'Sabtu';
        case 7: return 'Minggu';
        default: return '';
      }
    }
  }

  // Mengambil 5 hari unik untuk Prakiraan Harian (mengambil cuaca siang hari)
  List<ForecastItem> getDailyForecasts(List<ForecastItem> allForecasts) {
    final List<ForecastItem> daily = [];
    final Set<int> uniqueDays = {};

    for (final item in allForecasts) {
      final date = item.dateTime;
      final dayHash = date.year * 10000 + date.month * 100 + date.day;

      if (!uniqueDays.contains(dayHash)) {
        // Cari prakiraan yang paling mendekati jam 12:00 siang
        final middaySlot = allForecasts.firstWhere(
          (f) => f.dateTime.year == date.year &&
              f.dateTime.month == date.month &&
              f.dateTime.day == date.day &&
              f.dateTime.hour == 12,
          orElse: () => item,
        );
        daily.add(middaySlot);
        uniqueDays.add(dayHash);
      }
    }
    return daily;
  }

  // Dapatkan Label Kualitas Udara berdasarkan indeks (1-5)
  String getAqiLabel(int aqi) {
    switch (aqi) {
      case 1:
        return 'Sangat Baik';
      case 2:
        return 'Baik';
      case 3:
        return 'Sedang';
      case 4:
        return 'Buruk';
      case 5:
        return 'Sangat Buruk';
      default:
        return 'Tidak Diketahui';
    }
  }

  // Dapatkan Warna untuk indikator Kualitas Udara
  Color getAqiColor(int aqi) {
    switch (aqi) {
      case 1:
        return Colors.greenAccent.shade400;
      case 2:
        return Colors.lightGreenAccent.shade400;
      case 3:
        return Colors.amberAccent;
      case 4:
        return Colors.orangeAccent;
      case 5:
        return Colors.redAccent.shade200;
      default:
        return Colors.white70;
    }
  }

  // Dapatkan Icon Cuaca Utama dengan Animasi Halus
  Widget getWeatherIcon(String condition, String iconCode) {
    IconData iconData;
    Color iconColor = Colors.white;

    switch (condition.toLowerCase()) {
      case 'clear':
        iconData = Icons.wb_sunny_rounded;
        iconColor = const Color(0xFFF5A623); // Honey gold lembut (nyaman di mata)
        break;
      case 'clouds':
        iconData = Icons.wb_cloudy_rounded;
        iconColor = Colors.blueGrey.shade100;
        break;
      case 'rain':
      case 'drizzle':
        iconData = Icons.umbrella_rounded;
        iconColor = Colors.blue.shade200;
        break;
      case 'thunderstorm':
        iconData = Icons.thunderstorm_rounded;
        iconColor = Colors.amber.shade200;
        break;
      case 'snow':
        iconData = Icons.ac_unit_rounded;
        iconColor = Colors.lightBlue.shade100;
        break;
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
        iconData = Icons.blur_on_rounded;
        iconColor = Colors.grey.shade300;
        break;
      default:
        iconData = Icons.wb_cloudy_rounded;
        iconColor = Colors.white;
    }

    if (condition.toLowerCase() == 'clear' && !iconCode.endsWith('n')) {
      return _AnimatedSun(iconData: iconData, color: iconColor);
    } else if (condition.toLowerCase() == 'clouds') {
      return _AnimatedCloud(iconData: iconData, color: iconColor);
    } else if (condition.toLowerCase() == 'rain' || condition.toLowerCase() == 'drizzle') {
      return _AnimatedRain(iconData: iconData, color: iconColor);
    } else {
      return Icon(iconData, size: 90, color: iconColor, shadows: [
        Shadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))
      ]);
    }
  }

  // Widget Ikon untuk Prakiraan List
  Widget getForecastIconWidget(String condition) {
    IconData iconData;
    Color iconColor = Colors.white;

    switch (condition.toLowerCase()) {
      case 'clear':
        iconData = Icons.wb_sunny_rounded;
        iconColor = const Color(0xFFF5A623); // Honey gold lembut
        break;
      case 'clouds':
        iconData = Icons.wb_cloudy_rounded;
        iconColor = Colors.blueGrey.shade100;
        break;
      case 'rain':
      case 'drizzle':
        iconData = Icons.umbrella_rounded;
        iconColor = Colors.blue.shade200;
        break;
      case 'thunderstorm':
        iconData = Icons.thunderstorm_rounded;
        iconColor = Colors.amber.shade200;
        break;
      case 'snow':
        iconData = Icons.ac_unit_rounded;
        iconColor = Colors.lightBlue.shade100;
        break;
      default:
        iconData = Icons.wb_cloudy_rounded;
        iconColor = Colors.white;
    }
    return Icon(iconData, size: 28, color: iconColor);
  }

  // Search bar glassmorphic di bagian atas
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            _fetchWeatherByCity(value.trim());
          }
        },
        decoration: InputDecoration(
          hintText: 'Cari nama kota...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_searchController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                ),
              IconButton(
                icon: const Icon(Icons.my_location_rounded, color: Colors.white70),
                onPressed: () {
                  _searchController.clear();
                  _fetchWeatherByCurrentLocation();
                },
              ),
            ],
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  // Tampilan Informasi Detail Parameter Cuaca
  Widget _buildMetricsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                icon: Icons.water_drop_rounded,
                value: '${_weather!.humidity}%',
                label: 'Kelembapan',
                color: Colors.blue.shade200,
              ),
              _buildMetricDivider(),
              _buildMetricItem(
                icon: Icons.air_rounded,
                value: '${_weather!.windSpeed.toStringAsFixed(1)} m/s',
                label: 'Angin',
                color: Colors.teal.shade200,
              ),
              _buildMetricDivider(),
              _buildMetricItem(
                icon: Icons.compress_rounded,
                value: '${_weather!.pressure} hPa',
                label: 'Tekanan',
                color: Colors.orange.shade200,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricDivider() {
    return Container(
      height: 45,
      width: 1,
      color: Colors.white.withOpacity(0.15),
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // Tampilan Informasi Kualitas Udara (AQI) - BARU
  Widget _buildAqiCard() {
    final aqi = _weather!.aqi;
    final label = getAqiLabel(aqi);
    final color = getAqiColor(aqi);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.air_rounded, color: Colors.teal.shade100, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        "Kualitas Udara",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color, width: 1),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Horizontal progress dots
              Row(
                children: List.generate(5, (index) {
                  final barIndex = index + 1;
                  final isCurrent = barIndex == aqi;
                  return Expanded(
                    child: Container(
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: isCurrent ? color : Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: color.withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tampilan Rekomendasi Cuaca / Tips Hari Ini - BARU
  Widget _buildTipsCard() {
    String tipText =
        "Kondisi mendukung untuk aktivitas luar ruangan. Nikmati hari Anda!";
    IconData tipIcon = Icons.wb_sunny_outlined;
    Color iconColor = Colors.white;

    final condition = _weather!.mainCondition.toLowerCase();
    final temp = _weather!.temperature;

    if (condition == 'thunderstorm') {
      tipText =
          "Ada Hujan Badai! Tetaplah berada di dalam rumah dan cabut peralatan elektronik untuk keamanan.";
      tipIcon = Icons.bolt_rounded;
      iconColor = Colors.amber.shade300;
    } else if (condition == 'rain' || condition == 'drizzle') {
      tipText =
          "Sedang hujan. Siapkan payung ☔ atau jas hujan jika Anda berencana keluar!";
      tipIcon = Icons.umbrella_rounded;
      iconColor = Colors.blue.shade300;
    } else if (condition == 'clear') {
      if (temp > 28) {
        tipText =
            "Suhu cukup terik (${temp.round()}°C) ☀️. Gunakan tabir surya (sunscreen) dan minum air yang banyak agar terhindar dari dehidrasi.";
        tipIcon = Icons.wb_sunny_rounded;
        iconColor = Colors.amber;
      } else {
        tipText =
            "Cuaca cerah & sejuk (${temp.round()}°C). Hari yang indah untuk beraktivitas di luar!";
        tipIcon = Icons.emoji_emotions_outlined;
        iconColor = Colors.pink.shade200;
      }
    } else if (condition == 'clouds') {
      tipText =
          "Cuaca berawan. Nyaman untuk berolahraga outdoor atau sekadar jalan-jalan santai.";
      tipIcon = Icons.cloud_outlined;
      iconColor = Colors.blueGrey.shade100;
    } else if (condition == 'snow') {
      tipText =
          "Suhu sangat dingin! Gunakan pakaian berlapis, mantel tebal, dan sarung tangan.";
      tipIcon = Icons.ac_unit_rounded;
      iconColor = Colors.cyan.shade100;
    } else if (['mist', 'smoke', 'haze', 'dust', 'fog'].contains(condition)) {
      tipText =
          "Kabut membatasi jarak pandang. Kurangi kecepatan berkendara dan nyalakan lampu utama.";
      tipIcon = Icons.visibility_off_rounded;
      iconColor = Colors.grey.shade300;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(tipIcon, color: iconColor, size: 36),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tips Hari Ini",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tipText,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Tampilan Toggle Tab Cuaca (Per Jam vs Harian) - BARU
  Widget _buildForecastToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Prakiraan Cuaca',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isHourlyForecast = true;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _isHourlyForecast
                        ? Colors.white.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Per Jam',
                    style: TextStyle(
                      color: _isHourlyForecast ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isHourlyForecast = false;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: !_isHourlyForecast
                        ? Colors.white.withOpacity(0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Harian',
                    style: TextStyle(
                      color: !_isHourlyForecast ? Colors.white : Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tampilan Prakiraan Cuaca
  Widget _buildForecastSection() {
    if (_forecast.isEmpty) return const SizedBox.shrink();

    final List<ForecastItem> displayList = _isHourlyForecast
        ? _forecast.take(8).toList() // Tampilkan 24 jam ke depan (interval 3-jam)
        : getDailyForecasts(_forecast); // Tampilkan 5 hari harian

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildForecastToggle(),
        const SizedBox(height: 14),
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: displayList.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = displayList[index];
              return Container(
                width: 105,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 6.0,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _isHourlyForecast
                                ? formatDateTime(item.dateTime)
                                : formatToDayOnly(item.dateTime),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          getForecastIconWidget(item.mainCondition),
                          Text(
                            '${item.temp.round()}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            getIndonesianCondition(item.mainCondition, item.description),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Subteks Provinsi & Negara di bawah Nama Kota
  Widget _buildRegionSubtext() {
    final List<String> parts = [];
    if (_weather!.province.isNotEmpty) {
      parts.add(_weather!.province);
    }
    if (_weather!.country.isNotEmpty) {
      parts.add(_weather!.country);
    }

    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
            width: 1,
          ),
        ),
        child: Text(
          parts.join(', '),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }

  // Tampilan Body Utama
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            SizedBox(height: 16),
            Text(
              'Sedang mengambil data cuaca...',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 72,
                color: Colors.white70,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: _fetchWeatherByCurrentLocation,
              ),
            ],
          ),
        ),
      );
    }

    if (_weather == null) {
      return const Center(
        child: Text(
          'Tidak ada data cuaca.',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      color: Colors.white,
      backgroundColor: Colors.black26,
      onRefresh: () async {
        if (_searchController.text.isNotEmpty) {
          await _fetchWeatherByCity(_searchController.text);
        } else {
          await _fetchWeatherByCurrentLocation();
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Lokasi Kota
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 6),
                  Text(
                    _weather!.cityName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              _buildRegionSubtext(),
              const SizedBox(height: 8),
              // Hari & Tanggal
              Text(
                _getFormattedToday(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 28),
              // Visual Ikon Cuaca Animatif
              getWeatherIcon(_weather!.mainCondition, _weather!.iconCode),
              const SizedBox(height: 20),
              // Suhu
              Text(
                '${_weather!.temperature.round()}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 78,
                  fontWeight: FontWeight.w200,
                  height: 1.1,
                ),
              ),
              // Kondisi cuaca deskriptif & Feels Like
              Text(
                getIndonesianCondition(_weather!.mainCondition, _weather!.description),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Terasa seperti ${_weather!.feelsLike.round()}°C',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.65),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 35),
              // Card Details (Kelembapan, Angin, Tekanan)
              _buildMetricsCard(),
              const SizedBox(height: 20),
              // Card Kualitas Udara (AQI)
              _buildAqiCard(),
              const SizedBox(height: 20),
              // Card Rekomendasi / Tips Cuaca
              _buildTipsCard(),
              const SizedBox(height: 35),
              // Card Forecast Toggle & List
              _buildForecastSection(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _weather != null
        ? getBackgroundGradient(_weather!.mainCondition, _weather!.iconCode)
        : [const Color(0xFF2193b0), const Color(0xFF6dd5ed)];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// KUMPULAN ANIMASI MIKRO CUACA (NATIVE FLUTTER)
// ==========================================

class _AnimatedSun extends StatefulWidget {
  final IconData iconData;
  final Color color;
  const _AnimatedSun({required this.iconData, required this.color});

  @override
  State<_AnimatedSun> createState() => _AnimatedSunState();
}

class _AnimatedSunState extends State<_AnimatedSun>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(
        widget.iconData,
        size: 96,
        color: widget.color,
        shadows: [
          Shadow(
            color: widget.color.withOpacity(0.25), // Pendaran lebih lembut
            blurRadius: 18,
            offset: const Offset(0, 0),
          )
        ],
      ),
    );
  }
}

class _AnimatedCloud extends StatefulWidget {
  final IconData iconData;
  final Color color;
  const _AnimatedCloud({required this.iconData, required this.color});

  @override
  State<_AnimatedCloud> createState() => _AnimatedCloudState();
}

class _AnimatedCloudState extends State<_AnimatedCloud>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<Offset>(
      begin: const Offset(-0.06, 0.0),
      end: const Offset(0.06, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _animation,
      child: Icon(
        widget.iconData,
        size: 96,
        color: widget.color,
        shadows: [
          Shadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          )
        ],
      ),
    );
  }
}

class _AnimatedRain extends StatefulWidget {
  final IconData iconData;
  final Color color;
  const _AnimatedRain({required this.iconData, required this.color});

  @override
  State<_AnimatedRain> createState() => _AnimatedRainState();
}

class _AnimatedRainState extends State<_AnimatedRain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.9,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Icon(
        widget.iconData,
        size: 96,
        color: widget.color,
        shadows: [
          Shadow(
            color: widget.color.withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
    );
  }
}
