import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/media_item.dart';

class ServerService {
  static const String baseServerUrl = 'http://172.16.50.4/';
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 15)));

  Future<List<MediaItem>> fetchDirectory(String targetUrl) async {
    try {
      final response = await _dio.get(targetUrl);
      final document = html_parser.parse(response.data);
      final links = document.querySelectorAll('a');
      final List<MediaItem> items = [];

      for (var link in links) {
        final href = link.attributes['href'];
        final text = link.text.trim();
        if (href == null || href.startsWith('?') || href == '../' || href == '/') continue;
        final fullUrl = Uri.parse(targetUrl).resolve(href).toString();
        final isDir = href.endsWith('/') || !href.contains('.');
        items.add(MediaItem(name: text.isNotEmpty ? text : href, url: fullUrl, isDirectory: isDir));
      }
      return items;
    } catch (e) { throw Exception('BDIX Server Connection Failed.'); }
  }

  Future<List<MediaItem>> universalSearch(String startUrl, String query) async {
    final List<MediaItem> results = [];
    final List<String> foldersToSearch = [startUrl];
    int depthLimit = 40; 
    while (foldersToSearch.isNotEmpty && depthLimit > 0) {
      depthLimit--;
      String currentFolder = foldersToSearch.removeAt(0);
      try {
        final items = await fetchDirectory(currentFolder);
        for (var item in items) {
          if (item.name.toLowerCase().contains(query.toLowerCase())) results.add(item);
          if (item.isDirectory) foldersToSearch.add(item.url);
        }
      } catch (e) {}
    }
    return results;
  }
}