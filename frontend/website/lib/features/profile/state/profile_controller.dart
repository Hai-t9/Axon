import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/state/auth_session_provider.dart';
import '../data/profile_models.dart';

final profileProvider = Provider<ProfileData?>((ref) {
  final session = ref.watch(authSessionProvider);
  if (session == null) return null;
  return ProfileData.fromAuthSession({
    'id': session.user.id,
    'email': session.user.email,
    'fullname': session.user.fullname,
  });
});
