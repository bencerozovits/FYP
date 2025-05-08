import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'loginScreen.dart';
import 'package:fl_chart/fl_chart.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthScreen(),
    );
  }
}

class LCApp extends StatefulWidget {
  const LCApp({super.key});

  @override
  _LCAppState createState() => _LCAppState();
}

class _LCAppState extends State<LCApp> {
  ThemeMode _themeMode = ThemeMode.light;
  bool _isHighContrast = false;

  void _toggleTheme(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _toggleHighContrast(bool isHighContrast) {
    setState(() {
      _isHighContrast = isHighContrast;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      brightness: brightness,
      primaryColor: Colors.lightBlue,
      scaffoldBackgroundColor: _isHighContrast
          ? (isDark ? Colors.black : Colors.white)
          : (isDark ? Colors.black : Colors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: _isHighContrast ? Colors.black : null,
        foregroundColor: _isHighContrast ? Colors.white : null,
        titleTextStyle: TextStyle(
          fontSize: _isHighContrast ? 22 : 20,
          fontWeight: FontWeight.bold,
          color: _isHighContrast ? Colors.white : null,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Colors.lightBlue,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(
          fontSize: _isHighContrast ? 18 : 16,
          fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
          color: _isHighContrast
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white : Colors.black),
        ),
        titleLarge: TextStyle(
          fontSize: _isHighContrast ? 22 : 20,
          fontWeight: FontWeight.bold,
          color: _isHighContrast
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white : Colors.black),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: TextStyle(
            fontSize: _isHighContrast ? 18 : 16,
            fontWeight: _isHighContrast ? FontWeight.bold : FontWeight.normal,
          ),
          backgroundColor: _isHighContrast ? Colors.black : null,
          foregroundColor: _isHighContrast ? Colors.white : null,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(
          _isHighContrast ? Colors.lightBlueAccent : null,
        ),
        trackColor: WidgetStateProperty.all(
          _isHighContrast ? Colors.lightBlue.withAlpha((0.5 * 255).round()) : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: MainScreen(
        toggleTheme: _toggleTheme,
        toggleHighContrast: _toggleHighContrast,
        isDarkMode: _themeMode == ThemeMode.dark,
        isHighContrast: _isHighContrast,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final Function(bool) toggleHighContrast;
  final bool isDarkMode;
  final bool isHighContrast;

  const MainScreen({
    super.key,
    required this.toggleTheme,
    required this.toggleHighContrast,
    required this.isDarkMode,
    required this.isHighContrast,
  });

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isCameraButtonTapped = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _animateFab() {
    setState(() {
      _isCameraButtonTapped = true;
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      setState(() {
        _isCameraButtonTapped = false;
      });
    });
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'Tip: Upload a close-up of the neck tag or wash label for best results.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(imagePath: image.path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          const HistoryScreen(),
          const ProfileScreen(),
          SettingsScreen(
            toggleTheme: widget.toggleTheme,
            toggleHighContrast: widget.toggleHighContrast,
            isDarkMode: widget.isDarkMode,
            isHighContrast: widget.isHighContrast,
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1.0)),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(width: 4.0, color: Colors.lightBlue),
          ),
          labelColor: Colors.lightBlue,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.history), text: 'History'),
            Tab(icon: Icon(Icons.person), text: 'Profile'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: _isCameraButtonTapped ? 80.0 : 56.0,
        height: _isCameraButtonTapped ? 80.0 : 56.0,
        child: FloatingActionButton(
          backgroundColor: Colors.lightBlue,
          foregroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.black : Colors.white,
          onPressed: () {
            _animateFab();
            _showImagePicker();
          },
          child: const Icon(Icons.camera_alt, size: 28),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }
}

class ResultScreen extends StatefulWidget {
  final String imagePath;

  const ResultScreen({super.key, required this.imagePath});

  @override
  _ResultScreenState createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  String prediction = 'Loading...';
  Map<String, double> confidenceMap = {};
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    classifyImage();
  }

  Future<void> classifyImage() async {
    final uri = Uri.parse('http://192.168.0.251:5000/predict');

    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('image', widget.imagePath));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final predicted = data['prediction'];
        final confidenceRaw = Map<String, dynamic>.from(data['confidence']);
        final Map<String, double> confidence = confidenceRaw.map(
  (k, v) => MapEntry(k, (v as num).toDouble() * 100.0),
);

        setState(() {
          prediction = predicted;
          confidenceMap = confidence;
          isLoading = false;
        });

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final timestamp = DateTime.now().toIso8601String();
          final base64Image = base64Encode(await File(widget.imagePath).readAsBytes());
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('history')
              .add({
            'timestamp': timestamp,
            'prediction': prediction,
            'confidenceMap': confidence,
            'image' : base64Image,
          });
        }
      } else {
        setState(() {
          errorMessage = 'Error: ${response.body}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Widget buildConfidenceBar(String label, double value, bool isTop) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${value.toStringAsFixed(2)}%'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 12,
              backgroundColor: Colors.grey.shade300,
              color: isTop ? Colors.lightBlue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Legit Check Result')),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : errorMessage != null
                ? Text(errorMessage!)
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Image.file(File(widget.imagePath), height: 200),
                        const SizedBox(height: 20),
                        Text(
                          'Classification: $prediction',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        if (confidenceMap.isNotEmpty) ...[
                          const Text(
                            'Confidence Breakdown',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          buildConfidenceBar("Fake", confidenceMap["Fake"] ?? 0.0, prediction == "Fake"),
                          buildConfidenceBar("Real", confidenceMap["Real"] ?? 0.0, prediction == "Real"),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
onPressed: () async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final timestamp = DateTime.now().toIso8601String();
    final base64Image = base64Encode(await File(widget.imagePath).readAsBytes());

    await FirebaseFirestore.instance.collection('reportedPredictions').add({
      'userId': user.uid,
      'timestamp': timestamp,
      'prediction': prediction,
      'confidenceMap': confidenceMap,
      'image': base64Image,
    });
  }

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Report Submitted'),
      content: const Text('Thanks! Your feedback helps us improve accuracy.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
},
                          icon: const Icon(Icons.flag),
                          label: const Text('Report Incorrect Classification'),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class ResultHistoryScreen extends StatelessWidget {
  final String prediction;
  final Map<String, dynamic> confidenceMap;
  final String imageBase64;

  const ResultHistoryScreen({super.key, required this.prediction, required this.confidenceMap, required this.imageBase64});

  Widget buildConfidenceBar(String label, double value, bool isTop) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text('${value.toStringAsFixed(2)}%'),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 12,
              backgroundColor: Colors.grey.shade300,
              color: isTop ? Colors.lightBlue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double fakeConfidence = (confidenceMap['Fake'] as num?)?.toDouble() ?? 0.0;
    final double realConfidence = (confidenceMap['Real'] as num?)?.toDouble() ?? 0.0;

  return Scaffold(
    appBar: AppBar(title: const Text('Previous Check Result')),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (imageBase64.isNotEmpty)
            Image.memory(
              base64Decode(imageBase64),
              height: 200,
              fit: BoxFit.cover,
            ),
          const SizedBox(height: 20),
          Text('Classification: $prediction', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Confidence Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          buildConfidenceBar("Fake", fakeConfidence, prediction == "Fake"),
          buildConfidenceBar("Real", realConfidence, prediction == "Real"),
        ],
      ),
    ),
  );
}
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not logged in'));
    }

    final historyStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: historyStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No predictions yet.'));
        }

        final history = snapshot.data!.docs;

        return ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final data = history[index].data() as Map<String, dynamic>;
            final confidenceMap = Map<String, dynamic>.from(data['confidenceMap'] ?? {});
            final prediction = data['prediction'] ?? 'Unknown';
            final confidence = (confidenceMap[prediction] as num?)?.toDouble() ?? 0.0;

            final icon = (prediction == 'Fake' && confidence < 50)
              ? Icons.cancel_outlined
              : Icons.check_circle_outline;
            final iconColor = (prediction == 'Fake' && confidence < 50)
              ? Colors.red
              : Colors.green;

return ListTile(
  leading: Icon(icon, color: iconColor),
  title: Text('Date: ${data['timestamp'].toString().split("T")[0]}'),
  subtitle: Text('Prediction: $prediction, Confidence: ${confidence.toStringAsFixed(2)}%'),
  onTap: () {
    final imageBase64 = data['image'] ?? '';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultHistoryScreen(
          prediction: prediction,
          confidenceMap: confidenceMap,
          imageBase64 : imageBase64,
        ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<Map<String, dynamic>> _fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .get();

    final docs = snapshot.docs;
    if (docs.isEmpty) return {};

    int realCount = 0;
    int fakeCount = 0;
    double totalConfidence = 0.0;

    for (var doc in docs) {
      final data = doc.data();
      final prediction = data['prediction'];
      final confidenceMap = Map<String, dynamic>.from(data['confidenceMap'] ?? {});
      final confidence = (confidenceMap[prediction] as num?)?.toDouble() ?? 0.0;

      if (prediction == 'Real') {
        realCount++;
      } else if (prediction == 'Fake') {
        fakeCount++;
      }

      totalConfidence += confidence;
    }

    return {
      'email': user.email ?? '',
      'total': docs.length,
      'real': realCount,
      'fake': fakeCount,
      'averageConfidence': totalConfidence / docs.length,
      'lastCheck': docs.first.data()['timestamp']
    };
  }

  List<PieChartSectionData> _buildPieSections(int real, int fake, bool isDarkMode) {
    final total = real + fake;
    if (total == 0) return [];

    return [
      PieChartSectionData(
        color: isDarkMode ? Colors.blue[300] : Colors.lightBlue,
        value: real.toDouble(),
        title: 'Real',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        color: isDarkMode ? Colors.grey[600] : Colors.grey,
        value: fake.toDouble(),
        title: 'Fake',
        radius: 50,
        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = snapshot.data ?? {};

        if (stats.isEmpty) {
          return const Center(child: Text('No legit check data found.'));
        }

        final int real = stats['real'];
        final int fake = stats['fake'];

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Profile Summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text('Email: ${stats['email']}', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Total Checks: ${stats['total']}'),
                      const SizedBox(height: 8),
                      Text('Real: $real'),
                      Text('Fake: $fake'),
                      const SizedBox(height: 8),
                      Text('Avg. Confidence: ${stats['averageConfidence'].toStringAsFixed(2)}%'),
                      const SizedBox(height: 8),
                      Text('Last Check: ${stats['lastCheck'].toString().split("T").first}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AspectRatio(
                  aspectRatio: 1.2,
                  child: PieChart(
                    PieChartData(
                      sections: _buildPieSections(real, fake, isDarkMode),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SettingsScreen extends StatelessWidget {
  final Function(bool) toggleTheme;
  final Function(bool) toggleHighContrast;
  final bool isDarkMode;
  final bool isHighContrast;

  const SettingsScreen({
    super.key,
    required this.toggleTheme,
    required this.toggleHighContrast,
    required this.isDarkMode,
    required this.isHighContrast,
  });

  Future<void> _changeEmail(BuildContext context) async {
    final TextEditingController emailController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Email'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: 'New Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await user?.updateEmail(emailController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email updated successfully.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    final user = FirebaseAuth.instance.currentUser;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await user?.updatePassword(passwordController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password updated successfully.')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: isDarkMode,
            onChanged: toggleTheme,
          ),
          SwitchListTile(
            title: const Text('High Contrast Mode'),
            value: isHighContrast,
            onChanged: toggleHighContrast,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.email_outlined),
            label: const Text("Change Email"),
            onPressed: () => _changeEmail(context),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.lock_outline),
            label: const Text("Change Password"),
            onPressed: () => _changePassword(context),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text("Log Out"),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
