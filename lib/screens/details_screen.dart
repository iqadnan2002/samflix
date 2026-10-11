import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/media_item.dart';
import '../services/tmdb_service.dart';
import 'player_screen.dart';

class DetailsScreen extends StatefulWidget {
  final MediaItem item;
  final List<MediaItem> playlist;
  const DetailsScreen({super.key, required this.item, required this.playlist});
  @override
  State<DetailsScreen> createState() => _DetailsScreenState();
}

class _DetailsScreenState extends State<DetailsScreen> {
  final TMDbService _tmdb = TMDbService();
  String _fileSize = "Calculating size...";

  @override
  void initState() {
    super.initState();
    _fetchFileSize();
  }

  // Pings the BDIX server to get the exact file size without downloading the video
  Future<void> _fetchFileSize() async {
    try {
      final request = await HttpClient().headUrl(Uri.parse(widget.item.url));
      final response = await request.close();
      if (response.contentLength > 0) {
        final mb = response.contentLength / (1024 * 1024);
        if (mounted) {
          setState(() {
            _fileSize = mb > 1024 
                ? '${(mb / 1024).toStringAsFixed(2)} GB' 
                : '${mb.toStringAsFixed(1)} MB';
          });
        }
      } else {
        if (mounted) setState(() => _fileSize = 'Size unavailable');
      }
    } catch (e) {
      if (mounted) setState(() => _fileSize = 'Size unavailable');
    }
  }

  Future<void> _startBackgroundDownload() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.manageExternalStorage.request();
      await Permission.notification.request(); // Android 13+ requires this
    }
    
    final dir = await getExternalStorageDirectory();
    if (dir != null) {
      await FlutterDownloader.enqueue(
        url: widget.item.url,
        savedDir: dir.path,
        // Decode the filename so it saves with spaces instead of %20
        fileName: Uri.decodeComponent(widget.item.name), 
        showNotification: true,
        openFileFromNotification: true,
        saveInPublicStorage: true, 
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Download started. Check the Downloads tab.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _tmdb.getMetadata(widget.item.name),
        builder: (context, snapshot) {
          final meta = snapshot.data;
          final backdropUrl = meta?['backdrop'] ?? meta?['poster'];
          final tmdbTitle = meta?['title'];
          
          // Clean the raw server filename to use as the episode indicator
          final originalFileName = Uri.decodeComponent(widget.item.name).replaceAll(RegExp(r'\.mkv|\.mp4|\.avi'), '');
          final mainTitle = tmdbTitle ?? originalFileName;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400, pinned: true, backgroundColor: Colors.black,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      backdropUrl != null ? Image.network(backdropUrl, fit: BoxFit.cover, alignment: Alignment.topCenter) : Container(color: Colors.grey[900]),
                      Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, const Color(0xFF0F0F0F).withOpacity(1)], stops: const [0.4, 1.0]))),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mainTitle, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      
                      // If TMDB overwrote the title, show the actual episode/file name below it
                      if (tmdbTitle != null) ...[
                         const SizedBox(height: 8),
                         Text(originalFileName, style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                      
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                              icon: const Icon(Icons.play_arrow, size: 28), label: const Text('Play', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(item: widget.item, playlist: widget.playlist))),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                                    icon: const Icon(Icons.download, size: 28), label: const Text('Download', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    onPressed: _startBackgroundDownload,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Inject the fetched file size right under the button
                                Text(_fileSize, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      const Text('Overview', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(meta?['overview'] ?? 'No description available.', style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                      
                      if (meta != null && meta['cast'] != null && (meta['cast'] as List).isNotEmpty) ...[
                        const SizedBox(height: 30),
                        const Text('Cast', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: (meta['cast'] as List<dynamic>).map((actor) => Chip(label: Text(actor.toString(), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.white10, side: BorderSide.none)).toList(),
                        ),
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}