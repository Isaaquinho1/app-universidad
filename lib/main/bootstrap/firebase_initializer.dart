import 'package:firebase_core/firebase_core.dart';
import 'package:conecta_itt/firebase_options.dart';
import 'package:yx_scope/yx_scope.dart';

class FirebaseInitializer implements AsyncLifecycle {
  @override
  Future<void> init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Future<void> dispose() async {
    await Firebase.app().delete();
  }
}
