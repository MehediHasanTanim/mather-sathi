import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer. `tel:` needs no phone permission: the farmer still presses the call button.
abstract interface class Dialer {
  /// False when no dialer could be opened.
  Future<bool> dial(String number);
}

class UrlLauncherDialer implements Dialer {
  @override
  Future<bool> dial(String number) async {
    try {
      return await launchUrl(Uri(scheme: 'tel', path: number));
    } catch (_) {
      return false;
    }
  }
}

final dialerProvider = Provider<Dialer>((ref) => UrlLauncherDialer());
