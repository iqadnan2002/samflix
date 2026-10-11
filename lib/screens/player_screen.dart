import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/media_item.dart';


class PlayerScreen extends StatefulWidget {
  final MediaItem item;
  final List<MediaItem> playlist;

  const PlayerScreen({super.key, required this.item, required this.playlist});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  late MediaItem _currentItem;
  
  static const platform = MethodChannel('samflix/pip');
  
  double _subSize = 32.0;
  Color _subColor = Colors.white;
  bool _isLandscape = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentItem = widget.item;
    _player = Player();
    _controller = VideoController(_player);

    WakelockPlus.enable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    platform.invokeMethod('setPlayerState', true);
    
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPosition = prefs.getInt(_currentItem.url) ?? 0;

    await _player.open(Media(_currentItem.url));

    if (savedPosition > 0) {
      await _player.seek(Duration(milliseconds: savedPosition));
    }

    _player.stream.position.listen((pos) {
      if (pos.inSeconds % 5 == 0) prefs.setInt(_currentItem.url, pos.inMilliseconds);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    platform.invokeMethod('setPlayerState', false);
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  void _toggleRotation() {
    setState(() => _isLandscape = !_isLandscape);
    SystemChrome.setPreferredOrientations(_isLandscape 
        ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight] 
        : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey[900],
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) => ListTile(
          title: Text('${speed}x', style: const TextStyle(color: Colors.white, fontSize: 16)),
          onTap: () { _player.setRate(speed); Navigator.pop(ctx); },
        )).toList(),
      ),
    );
  }

  void _showAudioPicker() {
    final tracks = _player.state.tracks.audio;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey[900],
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(padding: EdgeInsets.all(16.0), child: Text('Audio Tracks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
          ...tracks.map((track) => ListTile(
            title: Text(track.title ?? track.language ?? track.id, style: const TextStyle(color: Colors.white70)),
            onTap: () { _player.setAudioTrack(track); Navigator.pop(ctx); },
          )),
        ],
      ),
    );
  }

  void _showSubtitlePicker() {
    final tracks = _player.state.tracks.subtitle;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey[900],
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(padding: EdgeInsets.all(16.0), child: Text('Subtitle Tracks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white))),
          ...tracks.map((track) => ListTile(
            title: Text(track.title ?? track.language ?? track.id, style: const TextStyle(color: Colors.white70)),
            onTap: () { _player.setSubtitleTrack(track); Navigator.pop(ctx); },
          )),
        ],
      ),
    );
  }

  void _showSubtitleSettings() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.grey[900],
      isScrollControlled: true, 
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subtitle Settings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Change Subtitle Track', style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  onTap: () { Navigator.pop(ctx); _showSubtitlePicker(); },
                ),
                const Divider(color: Colors.white24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Size', style: TextStyle(color: Colors.white, fontSize: 16)),
                    Slider(
                      value: _subSize, min: 16, max: 56, activeColor: Colors.redAccent,
                      onChanged: (v) { setModalState(() => _subSize = v); setState(() => _subSize = v); },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Color', style: TextStyle(color: Colors.white, fontSize: 16)),
                    Row(
                      children: [Colors.white, Colors.yellow, Colors.cyan].map((color) => GestureDetector(
                        onTap: () { setModalState(() => _subColor = color); setState(() => _subColor = color); },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4), width: 30, height: 30,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: _subColor == color ? Colors.redAccent : Colors.transparent, width: 2)),
                        ),
                      )).toList(),
                    )
                  ],
                ),
                const SizedBox(height: 40), 
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<String, List<MediaItem>> _groupEpisodesBySeason(List<MediaItem> playlist) {
    final Map<String, List<MediaItem>> seasons = {};
    for (var item in playlist.where((i) => i.isVideo)) {
      final match = RegExp(r'[S|s]eason[\s\._-]?(\d+)|[S|s](\d+)').firstMatch(item.name);
      final seasonNum = match != null ? (match.group(1) ?? match.group(2)) : 'Others';
      final seasonKey = seasonNum == 'Others' ? 'Extras / Movies' : 'Season $seasonNum';
      seasons.putIfAbsent(seasonKey, () => []).add(item);
    }
    return seasons;
  }

  @override
  Widget build(BuildContext context) {
    final groupedEpisodes = _groupEpisodesBySeason(widget.playlist);

    return Scaffold(
      backgroundColor: Colors.black,
      endDrawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(decoration: BoxDecoration(color: Colors.black87), child: Text('Seasons & Episodes', style: TextStyle(color: Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold))),
            ...groupedEpisodes.entries.map((entry) => ExpansionTile(
              title: Text(entry.key, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              iconColor: Colors.redAccent, collapsedIconColor: Colors.white70,
              children: entry.value.map((ep) => ListTile(
                title: Text(ep.name, style: TextStyle(color: ep.url == _currentItem.url ? Colors.redAccent : Colors.white70, fontSize: 13)),
                onTap: () { setState(() => _currentItem = ep); _initPlayer(); Navigator.pop(context); },
              )).toList(),
            )),
          ],
        ),
      ),
      // --- HERE IS THE FIX: Wrapped the entire video controls in a SafeArea ---
      body: SafeArea(
        child: MaterialVideoControlsTheme(
          normal: MaterialVideoControlsThemeData(
            volumeGesture: true,
            brightnessGesture: true,
            primaryButtonBar: [
              const Spacer(),
              IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 40), onPressed: () => _player.seek(_player.state.position - const Duration(seconds: 10))),
              const SizedBox(width: 24),
              const MaterialPlayOrPauseButton(iconSize: 56),
              const SizedBox(width: 24),
              IconButton(icon: const Icon(Icons.forward_10, color: Colors.white, size: 40), onPressed: () => _player.seek(_player.state.position + const Duration(seconds: 10))),
              const Spacer(),
            ],
            bottomButtonBar: const [
              MaterialPositionIndicator(),
              Spacer(),
              MaterialFullscreenButton(),
            ],
          ),
          fullscreen: const MaterialVideoControlsThemeData(volumeGesture: true, brightnessGesture: true),
          child: Stack(
            children: [
              Center(
                child: Video(
                  controller: _controller,
                  controls: MaterialVideoControls,
                  subtitleViewConfiguration: SubtitleViewConfiguration(
                    style: TextStyle(
                      fontSize: _subSize, color: _subColor, fontWeight: FontWeight.bold,
                      shadows: const [Shadow(blurRadius: 6.0, color: Colors.black, offset: Offset(2, 2))],
                    ),
                    textAlign: TextAlign.center, padding: const EdgeInsets.only(bottom: 30.0),
                  ),
                ),
              ),
              Positioned(
                top: 40, right: 60,
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(icon: const Icon(Icons.screen_rotation, color: Colors.white), onPressed: _toggleRotation, tooltip: 'Rotate'),
                      IconButton(icon: const Icon(Icons.speed, color: Colors.white), onPressed: _showSpeedPicker, tooltip: 'Speed'),
                      IconButton(icon: const Icon(Icons.audiotrack, color: Colors.white), onPressed: _showAudioPicker, tooltip: 'Audio'),
                      IconButton(icon: const Icon(Icons.subtitles, color: Colors.white), onPressed: _showSubtitleSettings, tooltip: 'Subtitles'),
                      Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => Scaffold.of(ctx).openEndDrawer(), tooltip: 'Episodes')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}