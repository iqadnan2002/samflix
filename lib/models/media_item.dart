class MediaItem {
  final String name;
  final String url;
  final bool isDirectory;

  MediaItem({required this.name, required this.url, required this.isDirectory});

  bool get isVideo {
    final lower = name.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.avi') || lower.endsWith('.webm') || lower.endsWith('.ts');
  }
}