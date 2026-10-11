import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class TMDbService {
  // Pulls the key dynamically from the .env file instead of hardcoding it
  static String apiKey = dotenv.env['TMDB_KEY'] ?? ''; 
  
  final Dio _dio = Dio();
  final Map<String, Map<String, dynamic>?> _cache = {};

  Future<Map<String, dynamic>?> getMetadata(String filename) async {
    if (_cache.containsKey(filename)) return _cache[filename];

    String cleanName = filename.replaceAll(RegExp(r'\.(mkv|mp4|avi|ts|webm)$'), ' ');
    cleanName = cleanName.replaceAll(RegExp(r'[\.\_]'), ' '); 
    cleanName = cleanName.replaceAll(RegExp(r'(1080p|720p|480p|2160p|x264|x265|BluRay|WEBRip|WEB-DL|HDTV|HDRip|S\d+E\d+|Season \d+|Episode \d+).*', caseSensitive: false), '');
    cleanName = cleanName.replaceAll(RegExp(r'\(\d{4}\)|\[.*?\]'), '');
    cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim(); 
    
    try {
      final response = await _dio.get(
        'https://api.themoviedb.org/3/search/multi',
        queryParameters: {'api_key': apiKey, 'query': cleanName},
      );

      if (response.data['results'] != null && response.data['results'].isNotEmpty) {
        final result = response.data['results'][0];
        final id = result['id'];
        final mediaType = result['media_type'];
        
        List<String> castMembers = [];
        if (id != null && mediaType != null && (mediaType == 'movie' || mediaType == 'tv')) {
          try {
            final castResponse = await _dio.get('https://api.themoviedb.org/3/$mediaType/$id/credits', queryParameters: {'api_key': apiKey});
            final castList = castResponse.data['cast'] as List;
            castMembers = castList.take(8).map((c) => c['name'] as String).toList();
          } catch (e) {}
        }

        final data = {
          'title': result['title'] ?? result['name'] ?? cleanName,
          'overview': result['overview'] ?? '',
          'poster': result['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${result['poster_path']}' : null,
          'backdrop': result['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/w1280${result['backdrop_path']}' : null,
          'cast': castMembers,
        };
        _cache[filename] = data;
        return data;
      }
    } catch (e) {}
    _cache[filename] = null;
    return null;
  }
}