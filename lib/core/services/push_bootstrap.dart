import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Registers this device for push once a profile exists and the user is not
/// blocked. Watching it from the home screen is enough to keep it alive.
final pushBootstrapProvider = Provider<void>((ref) {
  final me = ref.watch(appUserProvider).valueOrNull;
  if (me == null || me.blocked) return;
  ref.read(pushServiceProvider).register(me.uid);
});
