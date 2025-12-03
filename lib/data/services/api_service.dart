import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:io' show HttpClient;                 // only used for mobile
import 'package:dio/io.dart';                    // IO adapter
import 'package:dio/browser.dart';               // Web adapter

class ApiService {
  late final Dio _dio;

  ApiService() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://afasia.virtual.uniandes.edu.co/api',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
    ));

    if (kIsWeb) {
      // WEB: use BrowserHttpClientAdapter
      dio.httpClientAdapter = BrowserHttpClientAdapter();
    } else {
      // MOBILE: use IO adapter with cert override
      dio.httpClientAdapter = IOHttpClientAdapter()
        ..createHttpClient = () {
          final client = HttpClient();
          client.badCertificateCallback =
              (X509Certificate cert, String host, int port) => true;
          return client;
        };
    }

    _dio = dio;
  }

  Future<Response> post(String endpoint, Map<String, dynamic> data) async {
    return _dio.post(endpoint, data: data);
  }

  Future<Response> get(String endpoint) async {
    return _dio.get(endpoint);
  }
}
