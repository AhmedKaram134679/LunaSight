import 'package:luna_sight/features/home/domain/models/system_module.dart';

/// Contract for providing architectural and system roadmap information.
abstract class SystemModuleRepository {
  List<SystemModule> getSystemModules();
}

