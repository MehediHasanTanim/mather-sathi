class Upazila {
  const Upazila({required this.id, required this.nameBn, required this.nameEn});
  final int id;
  final String nameBn;
  final String nameEn;
}

class District {
  const District({
    required this.id,
    required this.slug,
    required this.nameBn,
    required this.nameEn,
    required this.lat,
    required this.lon,
    required this.upazilas,
  });

  final int id;
  final String slug; // used for FCM topics: d_<slug>
  final String nameBn;
  final String nameEn;
  final double lat;
  final double lon;
  final List<Upazila> upazilas;

  Upazila? upazilaById(String? id) {
    if (id == null) return null;
    for (final u in upazilas) {
      if ('${u.id}' == id) return u;
    }
    return null;
  }

  factory District.fromJson(Map<String, dynamic> j) => District(
        id: j['id'] as int,
        slug: j['slug'] as String,
        nameBn: j['name_bn'] as String,
        nameEn: j['name_en'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        upazilas: [
          for (final u in j['upazilas'] as List)
            Upazila(
              id: (u as Map)['id'] as int,
              nameBn: u['name_bn'] as String,
              nameEn: u['name_en'] as String,
            ),
        ],
      );
}
