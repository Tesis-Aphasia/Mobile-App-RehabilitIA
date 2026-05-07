// lib/services/image_cache_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  // Mapa normalizado: "pareja" → "https://storage.googleapis.com/..."
  Map<String, String> _cache = {};
  bool _loaded = false;

  String _normalize(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z\s]'), '')
      .trim();

  Future<void> load() async {
    if (_loaded) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('imagenes')
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final url = data['url'] as String?;
        final word = data['word'] as String?;
        if (url != null && url.isNotEmpty) {
          // Indexar por key del documento (ya normalizado)
          _cache[doc.id] = url;
          // También indexar por word normalizada por si acaso
          if (word != null) {
            _cache[_normalize(word)] = url;
          }
        }
      }
      _loaded = true;
    } catch (e) {
      // Si falla, simplemente no hay imágenes — no rompe la app
    }
  }

  /// Obtiene URL dada una palabra o key normalizada
  String? getUrl(String wordOrKey) {
    final key = _normalize(wordOrKey).replaceAll(' ', '_');
    return _cache[key] ?? _cache[_normalize(wordOrKey)];
  }

  /// Lista de palabras disponibles (para reemplazar _imageWords)
  List<String> get words => _cache.keys
      .map((k) => k.replaceAll('_', ' '))
      .toList();

  void invalidate() {
    _loaded = false;
    _cache.clear();
  }
}