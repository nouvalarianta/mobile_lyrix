import 'package:flutter/material.dart';
import 'package:lyrix/screens/splash_screen.dart';
import 'package:lyrix/theme/app_theme.dart';
import 'package:lyrix/services/pocketbase_service.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:lyrix/services/audio_player_service.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        Provider<PocketBase>(
          create: (context) => pb,
          dispose: (context, value) {
            print('PocketBase instance disposed');
          },
        ),
        ChangeNotifierProvider<AudioPlayerService>(
          create: (context) => AudioPlayerService(),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    pb.authStore.onChange.listen((_) {
      print('AuthStore changed event received in MyApp!');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyrix',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
