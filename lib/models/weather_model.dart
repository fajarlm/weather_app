class Weather {
  final String cityName;
  final String province;
  final String country;
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int pressure;
  final String mainCondition;
  final String description;
  final String iconCode;
  final int aqi; //air quality index (1-5, where 1 is good and 5 is very poor)

  Weather({
    required this.cityName,
    required this.province,
    required this.country,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.pressure,
    required this.mainCondition,
    required this.description,
    required this.iconCode,
    required this.aqi,
  });

  factory Weather.fromJson(Map<String, dynamic> json, {int aqi = 1, String province = '', String country = ''}) {
    String finalCountry = country;
    if (finalCountry.isEmpty && json['sys'] != null && json['sys']['country'] != null) {
      finalCountry = json['sys']['country'];
    }

    return Weather(
      cityName: json['name'] ?? 'Unknown',
      province: province,
      country: finalCountry,
      temperature: (json['main']['temp'] as num).toDouble(),
      feelsLike: (json['main']['feels_like'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      pressure: json['main']['pressure'] as int,
      mainCondition: json['weather'][0]['main'] ?? 'Clear',
      description: json['weather'][0]['description'] ?? '',
      iconCode: json['weather'][0]['icon'] ?? '01d',
      aqi: aqi,
    );
  }
}

class ForecastItem {
  final DateTime dateTime;
  final double temp;
  final String mainCondition;
  final String description;
  final String iconCode;

  ForecastItem({
    required this.dateTime,
    required this.temp,
    required this.mainCondition,
    required this.description,
    required this.iconCode,
  });

  factory ForecastItem.fromJson(Map<String, dynamic> json) {
    return ForecastItem(
      dateTime: DateTime.parse(json['dt_txt']),
      temp: (json['main']['temp'] as num).toDouble(),
      mainCondition: json['weather'][0]['main'] ?? 'Clear',
      description: json['weather'][0]['description'] ?? '',
      iconCode: json['weather'][0]['icon'] ?? '01d',
    );
  }
}