import '../../data/local_db/forge_database.dart';
import 'spec_drift_engine.dart';

class SpecDriftService {
  const SpecDriftService();

  Future<List<SpecDriftResult>> evaluate(List<Project> projects) async {
    final results = <SpecDriftResult>[];
    for (final project in projects) {
      try {
        final result = await SpecDriftEngine.evaluateProject(
          project.path,
          project.name,
        );
        if (result != null) results.add(result);
      } catch (_) {
      }
    }
    return results;
  }
}
