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
class HomePage extends StatefulWidget {
  final Store store;
  const HomePage({super.key, required this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  String _query = '';
  String? _tag;

  void _open([Dream? d]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPage(store: widget.store, dream: d),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final allTags = store.dreams.expand((d) => d.tags).toSet().toList()..sort();
    final tag = allTags.contains(_tag) ? _tag : null;
    final q = _query.trim();
    final shown = store.dreams.where((d) {
      final matchQ = q.isEmpty || d.title.contains(q) || d.body.contains(q);
      final matchT = tag == null || d.tags.contains(tag);
      return matchQ && matchT;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('متتبع الأحلام'),
        actions: [
          IconButton(
            tooltip: 'الوضع الداكن',
            icon: Icon(store.dark ? Icons.light_mode : Icons.dark_mode),
            onPressed: store.toggleDark,
          ),
        ],
      ),
      body: _tab == 0
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث في أحلامك',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (allTags.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final t in allTags)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: FilterChip(
                              label: Text(t),
                              selected: tag == t,
                              onSelected: (s) =>
                                  setState(() => _tag = s ? t : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: shown.isEmpty
                      ? Center(
                          child: Text(
                            store.dreams.isEmpty
                                ? 'ما سجّلت أي حلم بعد.\nاضغط "حلم جديد" للبدء.'
                                : 'لا توجد نتائج.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                          itemCount: shown.length,
                          itemBuilder: (context, i) {
                            final d = shown[i];
                            return Card(
                              child: ListTile(
                                leading: Text(
                                  moods[d.mood],
                                  style: const TextStyle(fontSize: 28),
                                ),
                                title: Text(d.title),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (d.body.isNotEmpty)
                                      Text(
                                        d.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      d.tags.isEmpty
                                          ? fmtDate(d.date)
                                          : '${fmtDate(d.date)}  •  ${d.tags.join('، ')}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                                onTap: () => _open(d),
                              ),
                            );
                          },
                        ),
                ),
              ],
            )
          : StatsPage(store: store),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _open,
              icon: const Icon(Icons.add),
              label: const Text('حلم جديد'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.nights_stay_outlined), label: 'الأحلام'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart), label: 'الإحصائيات'),
        ],
      ),
    );
  }
}

class StatsPage extends StatelessWidget {
  final Store store;
  const StatsPage({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final ds = store.dreams;
    if (ds.isEmpty) {
      return const Center(child: Text('سجّل بعض الأحلام لتظهر الإحصائيات.'));
    }
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final week = ds.where((d) => d.date.isAfter(weekAgo)).length;
    final avg = ds.map((d) => d.mood).reduce((a, b) => a + b) / ds.length;
    final counts = <String, int>{};
    for (final d in ds) {
      for (final t in d.tags) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final moodCounts =
        List.generate(5, (i) => ds.where((d) => d.mood == i).length);
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _StatCard(label: 'إجمالي الأحلام', value: '${ds.length}')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'آخر 7 أيام', value: '$week')),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                label: 'متوسط المزاج',
                value: moods[avg.round().clamp(0, 4)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('توزيع المزاج', style: titleStyle),
        const SizedBox(height: 8),
        for (var i = 0; i < 5; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text(moods[i])),
                SizedBox(width: 52, child: Text(moodLabels[i])),
                Expanded(
                  child: LinearProgressIndicator(
                    value: moodCounts[i] / ds.length,
                    minHeight: 10,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                SizedBox(
                  width: 32,
                  child: Text('${moodCounts[i]}', textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        Text('أكثر الوسوم تكرارًا', style: titleStyle),
        const SizedBox(height: 8),
        if (top.isEmpty)
          const Text('ما في وسوم بعد.')
        else
          for (final e in top.take(5))
            ListTile(
              dense: true,
              leading: const Icon(Icons.tag),
              title: Text(e.key),
              trailing: Text('${e.value}'),
            ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}


class EditorPage extends StatefulWidget {
  final Store store;
  final Dream? dream;
  const EditorPage({super.key, required this.store, this.dream});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _tags;
  late DateTime _date;
  late int _mood;

  @override
  void initState() {
    super.initState();
    final d = widget.dream;
    _title = TextEditingController(text: d?.title ?? '');
    _body = TextEditingController(text: d?.body ?? '');
    _tags = TextEditingController(text: d?.tags.join('، ') ?? '');
    _date = d?.date ?? DateTime.now();
    _mood = d?.mood ?? 2;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  List<String> _parseTags() => _tags.text
      .split(RegExp(r'[,،]'))
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  void _save() {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty && body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اكتب عنوانًا أو وصفًا للحلم أولًا')),
      );
      return;
    }
    widget.store.upsert(Dream(
      id: widget.dream?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'حلم بدون عنوان' : title,
      body: body,
      date: _date,
      mood: _mood,
      tags: _parseTags(),
    ));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحلم؟'),
        content: const Text('لا يمكن التراجع عن الحذف.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.store.remove(widget.dream!.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickDate() async {
    final p = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (p != null) setState(() => _date = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dream == null ? 'حلم جديد' : 'تعديل الحلم'),
        actions: [
          if (widget.dream != null)
            IconButton(
              tooltip: 'حذف',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          IconButton(
            tooltip: 'حفظ',
            icon: const Icon(Icons.check),
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'العنوان',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            minLines: 6,
            maxLines: 14,
            decoration: const InputDecoration(
              labelText: 'وصف الحلم',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const Text('المزاج'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 5; i++)
                ChoiceChip(
                  label: Text(moods[i], style: const TextStyle(fontSize: 22)),
                  selected: _mood == i,
                  onSelected: (_) => setState(() => _mood = i),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: 'الوسوم (افصل بينها بفاصلة)',
              hintText: 'طيران، مدرسة، حلم واضح',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text('التاريخ: ${fmtDate(_date)}'),
          ),
        ],
      ),
    );
  }
}
