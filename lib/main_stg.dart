import 'bootstrap.dart';
import 'firebase/options_stg.dart';

Future<void> main() => bootstrap(Flavor.stg, DefaultFirebaseOptions.currentPlatform);
