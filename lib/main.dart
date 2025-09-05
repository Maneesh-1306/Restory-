import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// 🔑 Gemini API Key (don’t hardcode in production!)
const String apiKey = 'AIzaSyA-RDvKFK7tu8Se6yN73AaqHy6RPJQDJKM';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ReStory',
      theme: ThemeData(
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

//
// 🔹 Splash Screen
//
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slide =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(_fade);

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StoryScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: const Text(
                "ReStory",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

//
// 🔹 Main Story Screen
//
class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final TextEditingController _controller = TextEditingController();
  List<String> _storyTitles = [];
  List<String> _fullStories = [];
  bool _isLoading = false;

  Future<void> _pickPdfAndExtractText() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);

        // Load PDF with Syncfusion
        final PdfDocument document =
        PdfDocument(inputBytes: await file.readAsBytes());
        String extractedText =
        PdfTextExtractor(document).extractText(); // ✅ Get text
        document.dispose();

        setState(() {
          _controller.text = extractedText;
        });
      }
    } catch (e) {
      _showError("Failed to pick or read PDF: $e");
    }
  }

  Future<void> _generateStories() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _storyTitles = [];
      _fullStories = [];
    });

    final String fullPrompt = """
    Given the following basic story description, create 5 different, elaborate, and distinct stories based on it.
    For each story, provide a title and the full story text.
    Format as:
    1. Title
    Story text
    
    Story Description: ${_controller.text}
    Directly give 5 stories, don't add additional texts like sure here are 5 stories....
    """;

    try {
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-05-20:generateContent?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": fullPrompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String generatedText =
        data['candidates'][0]['content']['parts'][0]['text'];

        final storiesData = generatedText
            .split(RegExp(r'(?:\n\s*)\d\. '))
            .where((s) => s.trim().isNotEmpty)
            .toList();

        List<String> titles = [];
        List<String> stories = [];

        for (var storyItem in storiesData) {
          final lines = storyItem.trim().split('\n');
          if (lines.length > 1) {
            titles.add(lines[0]);
            stories.add(lines.skip(1).join('\n').trim());
          }
        }

        setState(() {
          _storyTitles = titles;
          _fullStories = stories;
        });
      } else {
        _showError("Error: ${response.statusCode}");
      }
    } on SocketException {
      _showError("No internet connection.");
    } catch (e) {
      _showError("Unexpected error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ReStory"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Color(0xFFEDE7F6)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Enter a basic story idea...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickPdfAndExtractText,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Pick PDF"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: _isLoading ? null : _generateStories,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "✨ Generate 5 Stories",
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _storyTitles.isEmpty
                    ? const Center(
                  child: Text(
                    "Your stories will appear here ✨",
                    style:
                    TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                )
                    : ListView.builder(
                  itemCount: _storyTitles.length,
                  itemBuilder: (context, index) {
                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 5,
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      child: ListTile(
                        title: Text(
                          _storyTitles[index],
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        trailing: const Icon(
                            Icons.arrow_forward_ios_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => StoryDetailScreen(
                                title: _storyTitles[index],
                                story: _fullStories[index],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//
// 🔹 Story Detail Screen
//
class StoryDetailScreen extends StatelessWidget {
  final String title;
  final String story;

  const StoryDetailScreen({
    super.key,
    required this.title,
    required this.story,
  });

  Future<void> _shareAsPdf(BuildContext context) async {
    try {
      final PdfDocument document = PdfDocument();
      final page = document.pages.add();

      // ✅ Use PdfTextElement to handle wrapping + multi-page text
      final PdfFont font = PdfStandardFont(PdfFontFamily.helvetica, 14);
      final PdfTextElement textElement = PdfTextElement(
        text: "$title\n\n$story",
        font: font,
      );

      // Enable layout format so it flows to new pages automatically
      textElement.draw(
        page: page,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width,
            page.getClientSize().height),
        format: PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
        ),
      );

      final List<int> bytes = await document.save();
      document.dispose();

      final dir = await getTemporaryDirectory();
      final file = File("${dir.path}/$title.pdf");
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles([XFile(file.path)],
          text: "Check out this story: $title");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to share story: $e")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareAsPdf(context),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3E5F5), Color(0xFFEDE7F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 6,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  story,
                  textAlign: TextAlign.justify,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.6,
                    color: Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
