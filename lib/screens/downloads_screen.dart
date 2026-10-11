import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../models/media_item.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<DownloadTask>? _tasks;
  Timer? _timer;
  
  final Map<String, int> _lastSizes = {};
  final Map<String, String> _speeds = {};
  final Map<String, String> _downloadedMB = {};

  @override
  void initState() {
    super.initState();
    _loadTasks();
    // Poll every 1 second for live speed
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _loadTasks();
    });
  }

  // Bypass Scoped Storage blocks by guessing precise paths instead of listSync()
  File? _findActiveFile(String dir, String name) {
    final List<String> possiblePaths = [
      '$dir/$name',
      '$dir/${Uri.decodeComponent(name)}',
      '$dir/${Uri.decodeFull(name)}',
      '$dir/${name.replaceAll('+', ' ')}',
      '$dir/${Uri.decodeComponent(name).replaceAll('+', ' ')}'
    ];
    
    for (String path in possiblePaths) {
      final file = File(path);
      if (file.existsSync()) return file; // Found without directory read permissions!
    }
    return null;
  }

  Future<void> _loadTasks() async {
    final tasks = await FlutterDownloader.loadTasks();
    
    if (tasks != null) {
      for (var task in tasks) {
        if (task.status == DownloadTaskStatus.running && task.filename != null) {
          final file = _findActiveFile(task.savedDir, task.filename!);
          
          if (file != null && file.existsSync()) {
            final currentSize = file.lengthSync();
            final lastSize = _lastSizes[task.taskId] ?? currentSize;
            final bytesPerSecond = currentSize - lastSize;
            _lastSizes[task.taskId] = currentSize;

            _downloadedMB[task.taskId] = (currentSize / (1024 * 1024)).toStringAsFixed(1);
            
            // Fixed the syntax error on the multiplication calculation
            if (bytesPerSecond > 1024 * 1024) {
              _speeds[task.taskId] = '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else {
              _speeds[task.taskId] = '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
            }
          } else {
             _speeds[task.taskId] = 'Starting...';
          }
        }
      }
    }
    if (mounted) setState(() => _tasks = tasks);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Directly plays the offline video file securely
  void _playDownloadedFile(DownloadTask task) {
    if (task.status == DownloadTaskStatus.complete && task.filename != null) {
      
      final file = _findActiveFile(task.savedDir, task.filename!);

      if (file == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found! Android storage permissions may be blocking access.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }

      // Pass the verified absolute path directly to media_kit
      final mediaItem = MediaItem(name: task.filename!, url: file.path, isDirectory: false);
      
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlayerScreen(item: mediaItem, playlist: [mediaItem])),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(title: const Text('Downloads History', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.black),
      body: _tasks == null || _tasks!.isEmpty
          ? const Center(child: Text('No offline history', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _tasks!.length,
              itemBuilder: (context, index) {
                final task = _tasks![index];
                final isComplete = task.status == DownloadTaskStatus.complete;
                final speed = isComplete ? 'Offline Ready' : (_speeds[task.taskId] ?? '0 KB/s');
                final mb = isComplete ? '' : '${_downloadedMB[task.taskId] ?? '0.0'} MB';

                return GestureDetector(
                  onTap: () => _playDownloadedFile(task),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A), 
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isComplete ? Colors.green.withOpacity(0.5) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(task.filename ?? 'Unknown File', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 12),
                              LinearProgressIndicator(value: task.progress / 100, backgroundColor: Colors.black, color: isComplete ? Colors.green : Colors.redAccent, minHeight: 6, borderRadius: BorderRadius.circular(4)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(isComplete ? 'Tap to Play Offline' : '${task.progress}%  •  $mb', style: TextStyle(color: isComplete ? Colors.greenAccent : Colors.white70, fontSize: 13)),
                                  Text(speed, style: TextStyle(color: isComplete ? Colors.greenAccent : Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          children: [
                            if (task.status == DownloadTaskStatus.running)
                              IconButton(icon: const Icon(Icons.pause, color: Colors.orange), onPressed: () => FlutterDownloader.pause(taskId: task.taskId)),
                            if (task.status == DownloadTaskStatus.paused || task.status == DownloadTaskStatus.failed)
                              IconButton(icon: const Icon(Icons.play_arrow, color: Colors.green), onPressed: () => task.status == DownloadTaskStatus.failed ? FlutterDownloader.retry(taskId: task.taskId) : FlutterDownloader.resume(taskId: task.taskId)),
                            IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () {
                              FlutterDownloader.cancel(taskId: task.taskId);
                              FlutterDownloader.remove(taskId: task.taskId, shouldDeleteContent: true);
                              _loadTasks();
                            }),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}