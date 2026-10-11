import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../models/media_item.dart';
import '../services/server_service.dart';
import 'details_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ServerService _serverService = ServerService();
  late Future<List<MediaItem>> _rootFolders;

  @override
  void initState() {
    super.initState();
    // Fetch the root directory to build the main category tabs
    _rootFolders = _serverService.fetchDirectory(ServerService.baseServerUrl);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MediaItem>>(
      future: _rootFolders,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Color(0xFF0F0F0F), body: Center(child: CircularProgressIndicator(color: Colors.redAccent)));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Scaffold(
            backgroundColor: const Color(0xFF0F0F0F),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Could not connect to BDIX Server.', style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    onPressed: () => setState(() { _rootFolders = _serverService.fetchDirectory(ServerService.baseServerUrl); }),
                    child: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
            ),
          );
        }

        // Filter root items to only use directories as Tabs
        final tabs = snapshot.data!.where((item) => item.isDirectory).toList();

        return DefaultTabController(
          length: tabs.isEmpty ? 1 : tabs.length,
          child: Scaffold(
            backgroundColor: const Color(0xFF0F0F0F),
            appBar: AppBar(
              title: const Text('SAMFLIX', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 1.5)),
              backgroundColor: Colors.black,
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white, size: 28),
                  tooltip: 'Search',
                  onPressed: () {
                    showSearch(context: context, delegate: MediaSearchDelegate(_serverService));
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.home, color: Colors.white, size: 28),
                  tooltip: 'Home Root',
                  onPressed: () {
                    setState(() { _rootFolders = _serverService.fetchDirectory(ServerService.baseServerUrl); });
                  },
                ),
                const SizedBox(width: 8), // A little padding on the right edge
              ],
              bottom: tabs.isNotEmpty
                  ? TabBar(
                      isScrollable: true,
                      indicatorColor: Colors.redAccent,
                      labelColor: Colors.redAccent,
                      unselectedLabelColor: Colors.white70,
                      tabs: tabs.map((cat) => Tab(text: cat.name.toUpperCase())).toList(),
                    )
                  : null,
            ),
            body: tabs.isEmpty
                ? const Center(child: Text('No media folders found', style: TextStyle(color: Colors.white54)))
                : TabBarView(
                    // Pass the specific folder URL to fetch its actual contents
                    children: tabs.map((tab) => _FolderContent(url: tab.url, serverService: _serverService)).toList(),
                  ),
          ),
        );
      },
    );
  }
}

// Reusable widget that fetches and displays the actual files inside a folder
class _FolderContent extends StatefulWidget {
  final String url;
  final ServerService serverService;
  
  const _FolderContent({required this.url, required this.serverService});

  @override
  State<_FolderContent> createState() => _FolderContentState();
}

class _FolderContentState extends State<_FolderContent> {
  late Future<List<MediaItem>> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.serverService.fetchDirectory(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MediaItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Folder is empty', style: TextStyle(color: Colors.white54)));
        }

        final items = snapshot.data!;
        // Extract only the video files for the playlist if a video is tapped
        final videosOnly = items.where((i) => !i.isDirectory).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () {
                if (item.isDirectory) {
                  // Push deeper into the subfolder
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SubFolderScreen(url: item.url, title: item.name, serverService: widget.serverService),
                    ),
                  );
                } else {
                  // Open the actual movie/series file
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DetailsScreen(item: item, playlist: videosOnly)),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[900],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Center(
                          // Visual indicator: Yellow folder for directories, red movie icon for files
                          child: Icon(
                            item.isDirectory ? Icons.folder : Icons.movie, 
                            color: item.isDirectory ? Colors.amber : Colors.redAccent, 
                            size: 48
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        item.name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Standalone screen to handle navigating endlessly deep into subfolders
class SubFolderScreen extends StatelessWidget {
  final String url;
  final String title;
  final ServerService serverService;

  const SubFolderScreen({super.key, required this.url, required this.title, required this.serverService});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _FolderContent(url: url, serverService: serverService),
    );
  }
}


class MediaSearchDelegate extends SearchDelegate {
  final ServerService serverService;
  List<String> searchHistory = [];

  MediaSearchDelegate(this.serverService) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    searchHistory = prefs.getStringList('samflix_search_history') ?? [];
  }

  Future<void> _saveToHistory(String newQuery) async {
    if (newQuery.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    searchHistory.remove(newQuery);
    searchHistory.insert(0, newQuery);
    if (searchHistory.length > 10) searchHistory = searchHistory.sublist(0, 10); // Keep last 10
    await prefs.setStringList('samflix_search_history', searchHistory);
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: const Color(0xFF0F0F0F),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) {
    if (query.isEmpty) return const SizedBox();
    
    // Save the query to history immediately upon searching
    _saveToHistory(query);
    
    return FutureBuilder<List<MediaItem>>(
      future: serverService.universalSearch(ServerService.baseServerUrl, query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No results found.', style: TextStyle(color: Colors.white54)));
        
        final items = snapshot.data!;
        final videosOnly = items.where((i) => !i.isDirectory).toList();
        
        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: Icon(item.isDirectory ? Icons.folder : Icons.movie, color: item.isDirectory ? Colors.amber : Colors.redAccent),
              title: Text(item.name, style: const TextStyle(color: Colors.white)),
              onTap: () {
                if (item.isDirectory) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => SubFolderScreen(url: item.url, title: item.name, serverService: serverService)));
                } else {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(item: item, playlist: videosOnly)));
                }
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = query.isEmpty 
        ? searchHistory 
        : searchHistory.where((q) => q.toLowerCase().contains(query.toLowerCase())).toList();

    if (suggestions.isEmpty) return const SizedBox();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.history, color: Colors.white54),
          title: Text(suggestions[index], style: const TextStyle(color: Colors.white)),
          onTap: () {
            query = suggestions[index];
            showResults(context);
          },
        );
      },
    );
  }
}