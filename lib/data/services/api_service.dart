import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class ApiService {
  late final Dio _dio;

  ApiService() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://afasia.virtual.uniandes.edu.co/api',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ));

    dio.httpClientAdapter = IOHttpClientAdapter()
      ..createHttpClient = () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      };

    _dio = dio;
  }

  Future<Response> post(String endpoint, Map<String, dynamic> data) async {
    return _dio.post(endpoint, data: data);
  }

  Future<Response> get(String endpoint) async {
    return _dio.get(endpoint);
  }
}
