import 'bootstrap.dart';
import 'firebase/options_prod.dart';

Future<void> main() => bootstrap(Flavor.prod, DefaultFirebaseOptions.currentPlatform);
