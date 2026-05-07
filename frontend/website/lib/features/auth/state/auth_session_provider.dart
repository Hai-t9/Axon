import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_models.dart';
import 'auth_controller.dart';

final authSessionProvider = Provider<AuthSession?>((ref) {
  return ref.watch(authControllerProvider).valueOrNull;
});
