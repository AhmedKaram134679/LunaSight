import 'package:luna_sight/features/home/domain/models/system_module.dart';
import 'package:luna_sight/features/home/domain/repositories/system_module_repository.dart';

/// Local in-memory repository defining the actual status of LunaSight system capabilities.
///
/// Reflects the agreed LunaSight 11-phase implementation sequence:
/// Phase 01: Flutter Foundation (Operational)
/// Phase 02: NASA Data Integration (Operational)
/// Phase 03: Lunar Site Explorer (Operational)
/// Phase 04 through Phase 11: Planned capabilities without fabricated results or NASA data.
class LocalSystemModuleRepository implements SystemModuleRepository {
  const LocalSystemModuleRepository();

  @override
  List<SystemModule> getSystemModules() {
    return const [
      SystemModule(
        id: 'flutter_foundation',
        title: 'Flutter Foundation',
        description: 'Material 3 design system, responsive adaptive layout engine, decoupled routing, and production diagnostics.',
        phase: 'Phase 01',
        status: ModuleStatus.operational,
      ),
      SystemModule(
        id: 'nasa_data_integration',
        title: 'NASA Data Integration',
        description: 'Structured acquisition and caching of official lunar digital elevation, terrain, and planetary mission datasets.',
        phase: 'Phase 02',
        status: ModuleStatus.operational,
      ),
      SystemModule(
        id: 'lunar_site_explorer',
        title: 'Lunar Site Explorer',
        description: 'Interactive candidate site catalog, coordinates indexing, and geographic region classification.',
        phase: 'Phase 03',
        status: ModuleStatus.operational,
      ),
      SystemModule(
        id: 'scientific_geometry_engine',
        title: 'Scientific Geometry Engine',
        description: 'Astrometric calculations, sub-solar/sub-Earth vectors, and selenographic coordinate transformations.',
        phase: 'Phase 04 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'terrain_horizon_engine',
        title: 'Terrain Horizon Engine',
        description: 'Digital elevation model raycasting, local horizon elevation profile calculation, and terrain obstruction mapping.',
        phase: 'Phase 05 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'solar_illumination_analysis',
        title: 'Solar Illumination Analysis',
        description: 'Solar elevation modeling, time-series shadowing analysis, and persistent illumination window determination.',
        phase: 'Phase 06 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'earth_visibility_analysis',
        title: 'Earth Visibility Analysis',
        description: 'Direct-to-Earth line-of-sight verification, occultation evaluation, and communications coverage windows.',
        phase: 'Phase 07 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'mission_planning',
        title: 'Mission Planning',
        description: 'Operational landing epoch evaluation, traverse feasibility, and timeline constraint synchronization.',
        phase: 'Phase 08 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'site_comparison_scoring',
        title: 'Site Comparison & Scoring',
        description: 'Multi-criteria decision analysis matrix scoring candidate landing sites against mission constraints.',
        phase: 'Phase 09 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'dashboard_visualization',
        title: 'Dashboard & Visualization',
        description: 'Comprehensive telemetry charts, illumination timelines, elevation cross-sections, and site ranking summaries.',
        phase: 'Phase 10 (Planned)',
        status: ModuleStatus.planned,
      ),
      SystemModule(
        id: 'integration_final_release',
        title: 'Integration & Final Release',
        description: 'End-to-end analytical workflow validation, offline dataset verification, performance tuning, and release build.',
        phase: 'Phase 11 (Planned)',
        status: ModuleStatus.planned,
      ),
    ];
  }
}
