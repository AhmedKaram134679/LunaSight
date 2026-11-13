/// Status of architectural modules across implementation phases.
enum ModuleStatus { operational, planned }

/// Representation of a core LunaSight engineering or scientific module.
class SystemModule {
  final String id;
  final String title;
  final String description;
  final String phase;
  final ModuleStatus status;

  const SystemModule({
    required this.id,
    required this.title,
    required this.description,
    required this.phase,
    required this.status,
  });
}
