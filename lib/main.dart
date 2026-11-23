// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Universal Photo, Signature, Dimension & Document Engine

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/sarkari_theme.dart';
import 'ui/views/home/sarkari_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: SarkariTheme.darkBackground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const AuraResizeApp());
}

class AuraResizeApp extends StatelessWidget {
  const AuraResizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuraResize',
      debugShowCheckedModeBanner: false,
      theme: SarkariTheme.themeData,
      home: const SarkariHomeScreen(),
    );
  }
}
