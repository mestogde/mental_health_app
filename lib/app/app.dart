import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';

class MentalHealthApp extends StatelessWidget {
  const MentalHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ЦМЗ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const TestConnectionScreen(),
    );
  }
}

class TestConnectionScreen extends StatefulWidget {
  const TestConnectionScreen({super.key});

  @override
  State<TestConnectionScreen> createState() => _TestConnectionScreenState();
}

class _TestConnectionScreenState extends State<TestConnectionScreen> {
  final supabase = Supabase.instance.client;

  bool isLoading = true;
  String result = '';

  @override
  void initState() {
    super.initState();
    loadMaterials();
  }

  Future<void> loadMaterials() async {
    try {
      final data = await supabase
          .from('materials')
          .select('title, category, access_level')
          .eq('access_level', 'guest')
          .eq('publication_status', 'active');

      setState(() {
        result = data.toString();
        isLoading = false;
      });
    } catch (error) {
      setState(() {
        result = 'Ошибка подключения: $error';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: isLoading
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  child: Text(
                    result,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
        ),
      ),
    );
  }
}
