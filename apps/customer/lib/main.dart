import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash_screen.dart';
import 'services/api_client.dart';
import 'services/session.dart';
import 'theme.dart';

void main() {
  runApp(const SwiftDropApp());
}

class SwiftDropApp extends StatelessWidget {
  const SwiftDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient();
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<SessionState>(
          create: (_) => SessionState(api),
        ),
      ],
      child: MaterialApp(
        title: 'SwiftDrop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SplashScreen(),
      ),
    );
  }
}
