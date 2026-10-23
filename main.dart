import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const moods = ['😱', '😟', '😐', '🙂', '😍'];
const moodLabels = ['كابوس', 'مزعج', 'عادي', 'جميل', 'رائع'];

String fmtDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

class Dream {
  final String id;
  String title;
  String body;
  DateTime date;
  int mood;
  List<String> tags;

  Dream({
    required this.id,
    required this.title,
    required this.body,
    required this.date,
    required this.mood,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'date': date.toIso8601String(),
        'mood': mood,
        'tags': tags,
      };

  factory Dream.fromJson(Map<String, dynamic> j) => Dream(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String,
        date: DateTime.parse(j['date'] as String),
        mood: j['mood'] as int,
        tags: (j['tags'] as List).map((e) => e as String).toList(),
      );
}

class Store extends ChangeNotifier {
  List<Dream> dreams = [];
  bool dark = false;
  late SharedPreferences _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    dark = _prefs.getBool('dark') ?? false;
    final raw = _prefs.getString('dreams');
    if (raw != null) {
      dreams = (jsonDecode(raw) as List)
          .map((e) => Dream.fromJson(e as Map<String, dynamic>))
          .toList();
      _sort();
    }
  }

  void _sort() => dreams.sort((a, b) => b.date.compareTo(a.date));

  Future<void> _save() => _prefs.setString(
      'dreams', jsonEncode(dreams.map((d) => d.toJson()).toList()));

  void upsert(Dream d) {
    final i = dreams.indexWhere((x) => x.id == d.id);
    if (i >= 0) {
      dreams[i] = d;
    } else {
      dreams.add(d);
    }
    _sort();
    _save();
    notifyListeners();
  }

  void remove(String id) {
    dreams.removeWhere((d) => d.id == id);
    _save();
    notifyListeners();
  }

  void toggleDark() {
    dark = !dark;
    _prefs.setBool('dark', dark);
    notifyListeners();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  runApp(DreamApp(store: store));
}

class DreamApp extends StatelessWidget {
  final Store store;
  const DreamApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return MaterialApp(
          title: 'متتبع الأحلام',
          debugShowCheckedModeBanner: false,
          themeMode: store.dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
          ),
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
          home: HomePage(store: store),
        );
      },
    );
  }
}
