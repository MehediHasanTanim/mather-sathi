import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class KrishiApp extends StatelessWidget {
  const KrishiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'কৃষি সহায়',
      theme: buildAppTheme(),
      home: const Scaffold(body: Center(child: Text('কৃষি সহায়'))),
    );
  }
}
