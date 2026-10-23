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
        dat
