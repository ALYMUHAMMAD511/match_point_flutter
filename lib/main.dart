import 'dart:io';
import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoPlayerScreen(),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;

  int bluePoints = 0;
  int redPoints = 0;

  final TextEditingController urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _initializeController(VideoPlayerController controller) async {
    await _controller?.dispose();
    _chewieController?.dispose();

    _controller = controller;
    await _controller!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _controller!,
      autoPlay: true,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
    );

    setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    _chewieController?.dispose();
    urlController.dispose();
    super.dispose();
  }

  /// Load saved data
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      bluePoints = prefs.getInt("bluePoints") ?? 0;
      redPoints = prefs.getInt("redPoints") ?? 0;
    });

    final lastPath = prefs.getString("lastVideoPath");
    final isFile = prefs.getBool("isFile") ?? false;

    if (lastPath != null && lastPath.isNotEmpty) {
      if (isFile) {
        final file = File(lastPath);
        if (file.existsSync()) {
          _initializeController(VideoPlayerController.file(file));
        }
      } else {
        _initializeController(VideoPlayerController.network(lastPath));
      }
    }
  }

  Future<void> _savePoints() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("bluePoints", bluePoints);
    await prefs.setInt("redPoints", redPoints);
  }

  Future<void> _saveLastVideo(String path, bool isFile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("lastVideoPath", path);
    await prefs.setBool("isFile", isFile);
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Reset"),
        content: const Text("Reset points and clear last video?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Reset"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      setState(() {
        bluePoints = 0;
        redPoints = 0;
        _controller?.dispose();
        _controller = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ Data cleared successfully"),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _pickVideoFromStorage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      await _saveLastVideo(file.path, true);
      _initializeController(VideoPlayerController.file(file));
    }
  }

  bool _isDirectVideo(String url) {
    return url.endsWith(".mp4") ||
        url.endsWith(".m3u8") ||
        url.endsWith(".avi");
  }

  Future<void> _playFromUrl(String url) async {
    if (!_isDirectVideo(url)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("❌ Only direct .mp4 or .m3u8 links are supported"),
        ),
      );
      return;
    }
    if (url.isEmpty) return;

    try {
      await _saveLastVideo(url, false);
      await _initializeController(VideoPlayerController.network(url));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "❌ Failed to play video. Must be direct .mp4 or .m3u8 link.",
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _incrementBlue(int value) {
    setState(() {
      bluePoints += value;
    });
    _savePoints();
  }

  void _incrementRed(int value) {
    setState(() {
      redPoints += value;
    });
    _savePoints();
  }
  void _decrementRed(int value) {
    setState(() {
      redPoints -= value;
    });
    _savePoints();
  }

  void _decrementBlue(int value) {
    setState(() {
      bluePoints -= value;
    });
    _savePoints();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Match Point"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Reset All",
            onPressed: _confirmReset,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Fullscreen player area
            Expanded(
              child:
                  _chewieController != null &&
                      _chewieController!
                          .videoPlayerController
                          .value
                          .isInitialized
                  ? Stack(
                      children: [
                        Chewie(controller: _chewieController!),

                        // Overlay scoreboard buttons
                        Positioned(
                          bottom: -10,
                          left: 10,
                          right: 10,
                          child: Row(
                            children: [
                              // Blue team overlay
                              Expanded(
                                child: Container(
                                  color: Colors.blue.withOpacity(0.3),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Text(
                                        "$bluePoints",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _incrementBlue(1),
                                              child: const Text("1"),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _decrementBlue(1),
                                              child: const Text("-1"),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _incrementBlue(2),
                                              child: const Text("2"),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Red team overlay
                              Expanded(
                                child: Container(
                                  color: Colors.red.withOpacity(0.3),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    children: [
                                      Text(
                                        "$redPoints",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _incrementRed(1),
                                              child: const Text("1"),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _decrementRed(1),
                                              child: const Text("-1"),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () => _incrementRed(2),
                                              child: const Text("2"),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : const Center(
                      child: Text(
                        "No video selected",
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
            ),

            const Divider(color: Colors.white, height: 20),

            // Pick from storage
            ElevatedButton.icon(
              icon: const Icon(Icons.folder),
              label: const Text("Pick from Storage"),
              onPressed: _pickVideoFromStorage,
            ),

            // Play from URL
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Enter video URL (.mp4, .m3u8)",
                        hintStyle: TextStyle(color: Colors.grey),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.deepPurple),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _playFromUrl(urlController.text),
                    child: const Text("Play"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
