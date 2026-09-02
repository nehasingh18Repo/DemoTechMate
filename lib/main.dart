import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:brightspeed_fiber_app/app.dart';
import 'package:brightspeed_fiber_app/core/di/injection.dart';
import 'package:brightspeed_fiber_app/core/notifications/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error, stack) {
    debugPrint('Firebase init skipped/failed: $error\n$stack');
  }

  final dependencies = await AppDependencies.create();
  await dependencies.fcmService.initialize();

  runApp(
    MultiProvider(
      providers: dependencies.providers(),
      child: const TechMateApp(),
    ),
  );
}
