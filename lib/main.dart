import 'package:flutter/material.dart';

void main() {
  runApp(const SefCgApp());
}

class SefCgApp extends StatelessWidget {
  const SefCgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SefCG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SefCG'),
        backgroundColor: colorScheme.inversePrimary,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.phone_iphone,
                color: colorScheme.primary,
                size: 72,
              ),
              const SizedBox(height: 24),
              Text(
                'SefCG is ready for Flutter',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Build once in Dart and run on iOS and Android.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
