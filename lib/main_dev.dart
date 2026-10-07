import 'bootstrap.dart';
import 'firebase/options_dev.dart';

Future<void> main() => bootstrap(Flavor.dev, DefaultFirebaseOptions.currentPlatform);
