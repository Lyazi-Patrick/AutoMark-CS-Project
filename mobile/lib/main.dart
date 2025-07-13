import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobile/screens/unmarked_scripts.dart';
import 'package:provider/provider.dart';
import 'widgets/auth_guard.dart';

import 'firebase_options.dart';
import 'providers/answer_provider.dart';
import 'providers/result_provider.dart';

import 'screens/home_screen.dart';
import 'screens/upload_script_screen.dart';
import 'screens/answer_key_screen.dart';
import 'screens/result_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/unmarked_scripts.dart';
import 'screens/mark_script_screen.dart';
import 'screens/marked_scripts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const AutoMarkApp());
}

class AutoMarkApp extends StatelessWidget {
  const AutoMarkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AnswerProvider()),
        ChangeNotifierProvider(create: (_) => ResultProvider()),
      ],
      child: MaterialApp(
        title: 'AutoMark',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          useMaterial3: true,
        ),
        home: const AuthWrapper(), //  dynamic entry point
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/home': (context) => const AuthGuard(child: HomeScreen()),
          '/upload': (context) => const AuthGuard(child: UploadScriptScreen()),
          '/answer_key': (context) => const AuthGuard(child:AnswerKeyScreen()),
          '/result': (context) => const AuthGuard(child:ResultScreen()),
          '/scan': (context) => const AuthGuard(child: ScanScreen()),
          '/settings': (context) => const AuthGuard(child: SettingsScreen()),
          '/profile': (context) => const AuthGuard(child: ProfileScreen()),
          '/unmarked':(context) => const AuthGuard(child: UnmarkedScriptsScreen()),
          '/mark_script': (context) => AuthGuard(child: MarkScriptScreen()),
          '/marked_scripts': (context) => AuthGuard(child: MarkedScriptsScreen()),
        },
      ),
    );
  }
}

/// This decides whether to go to login or home automatically
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Waiting for Firebase to initialize
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in, show home
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Otherwise show login
        return const LoginScreen();
      },
    );
  }
}