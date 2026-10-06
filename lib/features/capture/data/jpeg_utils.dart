import 'dart:typed_data';

/// Dimensions from the JPEG SOF marker, read without decoding pixels.
/// Returns null when [b] is not a JPEG or the header is not within [b].
({int width, int height})? jpegSize(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return null;
  var i = 2;
  while (i + 4 <= b.length) {
    if (b[i] != 0xFF) return null;
    final m = b[i + 1];
    if (m == 0xFF) {
      i++; // fill byte
      continue;
    }
    if (m == 0xD8 || m == 0x01 || (m >= 0xD0 && m <= 0xD7)) {
      i += 2; // markers without a length
      continue;
    }
    if (m == 0xD9 || m == 0xDA) return null; // end of image / start of scan: no SOF seen
    final len = (b[i + 2] << 8) | b[i + 3];
    final isSof = m >= 0xC0 && m <= 0xCF && m != 0xC4 && m != 0xC8 && m != 0xCC;
    if (isSof) {
      if (i + 9 > b.length) return null;
      return (width: (b[i + 7] << 8) | b[i + 8], height: (b[i + 5] << 8) | b[i + 6]);
    }
    i += 2 + len;
  }
  return null;
}

bool _isMetadataMarker(int m) => m == 0xE1 /* EXIF, XMP */ || m == 0xED /* IPTC */;

/// True if the JPEG still carries an EXIF/XMP (APP1) or IPTC (APP13) segment.
bool hasMetadata(Uint8List b) {
  if (b.length < 4 || b[0] != 0xFF || b[1] != 0xD8) return false;
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF) {
    final m = b[i + 1];
    if (m == 0xFF) {
      i++;
      continue;
    }
    if (m == 0xDA || m == 0xD9) return false;
    if (_isMetadataMarker(m)) return true;
    i += 2 + ((b[i + 2] << 8) | b[i + 3]);
  }
  return false;
}

/// Removes EXIF/XMP (APP1) and IPTC (APP13) segments, keeping everything else
/// (including the ICC profile). Defence in depth: the native encoder already
/// drops EXIF, this guarantees no location data leaves the device.
/// Returns [b] unchanged if it is not a well-formed JPEG header.
Uint8List stripMetadata(Uint8List b) {
  if (!hasMetadata(b)) return b;
  final out = BytesBuilder(copy: false)..add(const [0xFF, 0xD8]);
  var i = 2;
  while (i + 4 <= b.length && b[i] == 0xFF) {
    final m = b[i + 1];
    if (m == 0xFF) {
      i++;
      continue;
    }
    if (m == 0xDA || m == 0xD9) break;
    final end = i + 2 + ((b[i + 2] << 8) | b[i + 3]);
    if (end > b.length) return b; // truncated: leave untouched
    if (!_isMetadataMarker(m)) out.add(Uint8List.sublistView(b, i, end));
    i = end;
  }
  out.add(Uint8List.sublistView(b, i)); // scan data to the end
  return out.toBytes();
}
