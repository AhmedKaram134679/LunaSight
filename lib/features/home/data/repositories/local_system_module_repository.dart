import 'package:luna_sight/features/home/domain/models/system_module.dart';
import 'package:luna_sight/features/home/domain/repositories/system_module_repository.dart';

/// Local in-memory repository defining the actual status of LunaSight system capabilities.
///
/// Clearly distinguishes Phase 01 operational foundations from planned future phases,
/// without fabricating NASA data or scientific calculations.
class LocalSystemModuleRepository implements SystemModuleRepository {
  const LocalSystemModuleRepository();

  @override
  List<SystemModule> getSystemModules() {
    return const [
      SystemModule(
        id: 'flutter_foundation',
        title: 'Core Flutter Architecture',
        description: 'Material 3 design system, responsive layout engine, decoupled routing, and error diagnostics foundation.',
        phase: 'Phase 01',
        status: ModuleStatus.operational,
      ),
      SystemModule(
        id: 'scientific_engine',
        title: 'Scientific Engine & Lunar Ephemeris',
        description: 'Astrometric calculations, solar vector determination, and coordinate frame transformations.',
        phase: 'Phase 02 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'terrain_analysis',
        title: 'Terrain & Elevation Analysis',
        description: 'Digital elevation model processing, slope computation, and landing hazard identification.',
        phase: 'Phase 03 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'illumination_engine',
        title: 'Illumination & Earth Visibility',
        description: 'Line-of-sight analysis for direct-to-Earth communication and persistent solar illumination windows.',
        phase: 'Phase 04 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'landing_site_evaluator',
        title: 'Multi-Criteria Site Evaluator',
        description: 'Weighted analytical decision matrix ranking optimal lunar landing sites and traverse pathways.',
        phase: 'Phase 05 (Planned)',
        status: ModuleStatus.planned,
      ),
    ];
  }
}
