import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherData {
  final double temp;
  final int humidity;
  final bool isRaining;
  final String description;
  final String city;
  final String recommendation; // Recomendação agronômica

  WeatherData({
    required this.temp,
    required this.humidity,
    required this.isRaining,
    required this.description,
    required this.city,
    required this.recommendation,
  });
}

class WeatherService {
  // Use sua chave real da OpenWeatherMap aqui para produção
  final String _apiKey = 'SUA_CHAVE_AQUI';

  Future<WeatherData> getSmartWeather() async {
    try {
      // 1. Tenta pegar GPS real
      Position pos = await _determinePosition();

      // 2. Se tiver API Key, chama o serviço real. Se não, simula dados coerentes.
      if (_apiKey == 'SUA_CHAVE_AQUI') {
        // MOCK DE ALTA FIDELIDADE (Para você testar sem configurar API agora)
        // Simulação: Dia quente = precisa de rega
        return WeatherData(
          temp: 29.5,
          humidity: 45,
          isRaining: false,
          description: 'Céu limpo',
          city: 'Sua Localização (Simulada)',
          recommendation:
              '⚠️ Umidade baixa e calor. Reforce a irrigação hoje (5mm).',
        );
      } else {
        // CHAMADA REAL
        final url = Uri.parse(
            'https://api.openweathermap.org/data/2.5/weather?lat=${pos.latitude}&lon=${pos.longitude}&appid=$_apiKey&units=metric&lang=pt_br');
        final response = await http.get(url);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final temp = (data['main']['temp'] as num).toDouble();
          final hum = (data['main']['humidity'] as int);
          final weatherId = (data['weather'][0]['id'] as int);
          final isRaining = weatherId < 700; // Códigos 2xx, 3xx, 5xx

          // Lógica Agronômica (Baseada nos E-books)
          String rec = "Mantenha o turno de rega normal.";
          if (isRaining)
            rec = "🌧️ Chuva detectada. Suspenda a rega para evitar fungos.";
          else if (temp > 28 && hum < 50)
            rec = "☀️ Alerta de calor! Aumente a lâmina d'água.";

          return WeatherData(
            temp: temp,
            humidity: hum,
            isRaining: isRaining,
            description: data['weather'][0]['description'],
            city: data['name'],
            recommendation: rec,
          );
        }
      }
    } catch (e) {
      print('Erro Weather: $e');
    }

    // Fallback de segurança
    return WeatherData(
        temp: 25,
        humidity: 60,
        isRaining: false,
        description: '-',
        city: 'Fazenda',
        recommendation: 'Verifique a umidade do solo manualmente.');
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS desativado.');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        return Future.error('Permissão negada.');
    }
    return await Geolocator.getCurrentPosition();
  }
}
