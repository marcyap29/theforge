import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'spec_notifier.dart';

final specNotifierProvider =
    NotifierProvider.autoDispose<SpecNotifier, SpecGenState>(SpecNotifier.new);
