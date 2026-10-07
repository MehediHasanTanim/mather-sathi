import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/district.dart';

List<District> parseDistricts(String json) => [
      for (final d in jsonDecode(json) as List)
        District.fromJson(d as Map<String, dynamic>),
    ];

final districtsProvider = FutureProvider<List<District>>((ref) async =>
    parseDistricts(await rootBundle.loadString('assets/data/districts.json')));
