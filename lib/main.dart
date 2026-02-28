import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:match_finder/screens/battery.dart';
import 'package:match_finder/screens/display.dart';
import 'package:match_finder/screens/phone_cover.dart';
import 'package:match_finder/screens/screen_guard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyADxLPXQvAE9ogJBMsWvded1A-WXQdICDY",
      authDomain: "matching-88e2d.firebaseapp.com",
      projectId: "matching-88e2d",
      storageBucket: "matching-88e2d.firebasestorage.app",
      messagingSenderId: "140726534050",
      appId: "1:140726534050:web:6e20dfe76bc7a77e677cfb",
      measurementId: "G-9DDW6BFMMH",
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Match Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF2563EB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1F2937),
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Match Finder',
          style: TextStyle(fontSize: 18), // Decreased from default
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), // Reduced from 20
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Simple header
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 20, // Decreased from 24
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 2), // Reduced from 4
              Text(
                'Select a category to manage',
                style: TextStyle(
                  fontSize: 12, // Decreased from 14
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16), // Reduced from 24
              // Categories grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12, // Reduced from 16
                mainAxisSpacing: 12, // Reduced from 16
                childAspectRatio: 1,
                children: [
                  _buildCategoryCard(
                    context,
                    icon: Icons.shield_rounded,
                    title: 'Screen Guard',
                    color: const Color(0xFF2563EB),
                    screen: const ScreenGuardTab(),
                  ),
                  _buildCategoryCard(
                    context,
                    icon: Icons.phone_iphone_rounded,
                    title: 'Phone Cover',
                    color: const Color(0xFF059669),
                    screen: const PhoneCoverTab(),
                  ),
                  _buildCategoryCard(
                    context,
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Battery',
                    color: const Color(0xFFD97706),
                    screen: const BatteryTab(),
                  ),
                  _buildCategoryCard(
                    context,
                    icon: Icons.connected_tv_rounded,
                    title: 'Display',
                    color: const Color(0xFF7C3AED),
                    screen: const DisplayTab(),
                  ),
                ],
              ),
              const SizedBox(height: 24), // Reduced from 32

              // Recent Activity section
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required Widget screen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16), // Reduced from 20
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8, // Reduced from 10
            offset: const Offset(0, 3), // Reduced from (0, 4)
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16), // Reduced from 20
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    DetailScreen(title: title, child: screen, color: color),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16), // Reduced from 20
          child: Container(
            padding: const EdgeInsets.all(12), // Reduced from 16
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12), // Reduced from 16
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12), // Reduced from 16
                  ),
                  child: Icon(icon, color: color, size: 24), // Reduced from 32
                ),
                const SizedBox(height: 8), // Reduced from 12
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13, // Decreased from 16
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityTile(
    String title,
    String subtitle,
    String time,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced from 16
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8), // Reduced from 12
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8), // Reduced from 12
            ),
            child: Icon(icon, color: color, size: 16), // Reduced from 20
          ),
          const SizedBox(width: 12), // Reduced from 16
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13, // Decreased from 15
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2), // Reduced from 4
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11, // Decreased from 13
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontSize: 10, // Decreased from 12
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Detail Screen
class DetailScreen extends StatelessWidget {
  final String title;
  final Widget child;
  final Color color;

  const DetailScreen({
    super.key,
    required this.title,
    required this.child,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: const Color(0xFFF8FAFC), body: child);
  }
}
