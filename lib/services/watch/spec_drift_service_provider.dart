import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'spec_drift_service.dart';

final specDriftServiceProvider = Provider<SpecDriftService>(
  (ref) => const SpecDriftService(),
);
