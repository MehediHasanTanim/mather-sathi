import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mather_sathi/features/geo/data/districts_repository.dart';

void main() {
  test('districts.json: 64 districts, unique slugs, every district has upazilas', () {
    final list = parseDistricts(File('assets/data/districts.json').readAsStringSync());
    expect(list.length, 64);
    expect(list.map((d) => d.slug).toSet().length, 64);
    expect(list.every((d) => d.upazilas.isNotEmpty), isTrue);
    expect(list.every((d) => RegExp(r'^[a-z0-9-]+$').hasMatch(d.slug)), isTrue);
    final dhaka = list.firstWhere((d) => d.slug == 'dhaka');
    expect(dhaka.upazilaById('${dhaka.upazilas.first.id}'), isNotNull);
    expect(dhaka.upazilaById('999999'), isNull);
  });
}
