import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/repositories/lunar_site_repository.dart';
import 'package:luna_sight/features/lunar_sites/domain/services/lunar_map_coordinates_helper.dart';
import 'package:luna_sight/features/solar_earth_visibility/domain/services/celestial_visibility_service.dart';

/// Interactive Mission Time Planner Page.
///
/// Models mission duration windows, solar illumination intervals, Earth direct-to-Earth (DTE)
/// communication coverage, and planned operational milestones for lunar south pole landing sites.
class MissionTimePlannerPage extends StatefulWidget {
  final LunarSite? initialSite;
  final LunarSiteRepository repository;
  final CelestialVisibilityService visibilityService;

  const MissionTimePlannerPage({
    super.key,
    this.initialSite,
    required this.repository,
    this.visibilityService = const CelestialVisibilityService(),
  });

  @override
  State<MissionTimePlannerPage> createState() => _MissionTimePlannerPageState();
}

class _MissionTimePlannerPageState extends State<MissionTimePlannerPage> {
  final LunarMapCoordinatesHelper _coordsHelper =
      const LunarMapCoordinatesHelper();

  List<LunarSite> _sites = [];
  LunarSite? _selectedSite;
  bool _isLoading = true;

  DateTime _missionEpoch = DateTime.utc(2026, 9, 15, 12, 0);
  double _durationDays = 14.0; // 14-day lunar daylight period
  double _currentTimeOffsetHours = 48.0; // Current cursor position

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    setState(() => _isLoading = true);
    try {
      final allSites = await widget.repository.getAllSites();
      if (!mounted) return;
      setState(() {
        _sites = allSites;
        if (widget.initialSite != null) {
          _selectedSite = allSites.firstWhere(
            (s) => s.id == widget.initialSite!.id,
            orElse: () => widget.initialSite!,
          );
        } else if (allSites.isNotEmpty) {
          _selectedSite = allSites.firstWhere(
            (s) => s.siteCode == 'Site04',
            orElse: () => allSites.first,
          );
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _missionEpoch,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (!mounted) return;
    if (pickedDate != null) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_missionEpoch),
      );
      if (!mounted) return;
      if (pickedTime != null) {
        setState(() {
          _missionEpoch = DateTime.utc(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = ResponsiveLayout.isCompact(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final site = _selectedSite;
    final point = site != null ? _coordsHelper.getMapPoint(site) : null;
    final lat = point?.latitude ?? -89.9;
    final lon = point?.longitude ?? 0.0;

    final totalHours = _durationDays * 24.0;
    final windows = widget.visibilityService.generateMissionWindows(
      latitudeDeg: lat,
      longitudeDeg: lon,
      totalDurationHours: totalHours,
      timeStepHours: 4.0,
    );

    final currentState = widget.visibilityService.computeVisibility(
      latitudeDeg: lat,
      longitudeDeg: lon,
      epochHours: _currentTimeOffsetHours,
      calendarDate: _missionEpoch.add(
        Duration(milliseconds: (_currentTimeOffsetHours * 3600 * 1000).round()),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Time Planner'),
        actions: [
          IconButton(
            tooltip: 'Select Target Mission Epoch',
            icon: const Icon(Icons.event_rounded),
            onPressed: _selectDate,
          ),
          const SizedBox(width: AppConstants.space8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact
                    ? AppConstants.space16
                    : AppConstants.space24,
                vertical: AppConstants.space16,
              ),
              children: [
                // 1. Mission Configuration Header Card
                _buildMissionConfigCard(context),
                const SizedBox(height: AppConstants.space16),

                // 2. Interactive Multi-Track Timeline & Gantt Chart
                _buildTimelineGanttChart(context, windows, totalHours),
                const SizedBox(height: AppConstants.space16),

                // 3. Current Epoch Scrubber Status Card
                _buildInstantTelemetryCard(context, currentState),
                const SizedBox(height: AppConstants.space20),

                // 4. Mission Operational Milestones
                _buildOperationalMilestonesCard(context, totalHours),
                const SizedBox(height: AppConstants.space20),

                // 5. Power & Battery Margin Simulator
                _buildPowerBudgetCard(context, currentState),
                const SizedBox(height: AppConstants.space20),

                // 6. Scientific Provenance & Mode Notice
                _buildIntegrityPolicyCard(context),
                const SizedBox(height: AppConstants.space24),

                // 7. Action Button: Open Visibility Analysis
                Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_selectedSite != null) {
                        Navigator.of(context)
                            .pushNamed('/visibility', arguments: _selectedSite);
                      }
                    },
                    icon: const Icon(Icons.wb_sunny_rounded),
                    label: const Text(
                      'Open 3D Celestial Visibility at this Epoch',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.space24,
                        vertical: AppConstants.space16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.space32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissionConfigCard(BuildContext context) {
    final theme = Theme.of(context);
    final formattedEpoch =
        '${_missionEpoch.year}-${_missionEpoch.month.toString().padLeft(2, '0')}-${_missionEpoch.day.toString().padLeft(2, '0')} ${_missionEpoch.hour.toString().padLeft(2, '0')}:${_missionEpoch.minute.toString().padLeft(2, '0')} UTC';

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag_circle_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: AppConstants.space8),
              Text(
                'Artemis Lunar Mission Parameters',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const StatusBadge(
                label: 'WINDOW PLANNING',
                color: AppColors.darkPrimary,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space16),
          // Target Site Row
          Row(
            children: [
              Text(
                'Target Site:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: AppConstants.space12),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedSite?.id,
                    items: _sites.map((site) {
                      return DropdownMenuItem<String>(
                        value: site.id,
                        child: Text(
                          '${site.name} (${site.siteCode})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        setState(() {
                          _selectedSite = _sites.firstWhere(
                            (s) => s.id == newId,
                          );
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppConstants.space16),
          // Epoch & Duration Pickers
          Wrap(
            spacing: AppConstants.space16,
            runSpacing: AppConstants.space8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 16),
                label: Text('Epoch: $formattedEpoch'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Duration: '),
                  ChoiceChip(
                    label: const Text('7 Days'),
                    selected: _durationDays == 7.0,
                    onSelected: (val) => setState(() => _durationDays = 7.0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('14 Days'),
                    selected: _durationDays == 14.0,
                    onSelected: (val) => setState(() => _durationDays = 14.0),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('28 Days'),
                    selected: _durationDays == 28.0,
                    onSelected: (val) => setState(() => _durationDays = 28.0),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineGanttChart(
    BuildContext context,
    List<VisibilityTimeWindow> windows,
    double totalHours,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Solar Illumination & Earth Comm Timeline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'T+${_currentTimeOffsetHours.toStringAsFixed(1)}h (${(_currentTimeOffsetHours / 24.0).toStringAsFixed(1)}d)',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: AppColors.darkPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),

          // Interactive Timeline Scrubber Slider
          Slider(
            value: _currentTimeOffsetHours.clamp(0.0, totalHours),
            min: 0.0,
            max: totalHours,
            divisions: (totalHours / 2).toInt(),
            label: 'T+${_currentTimeOffsetHours.toStringAsFixed(0)}h',
            onChanged: (newVal) {
              setState(() {
                _currentTimeOffsetHours = newVal;
              });
            },
          ),

          const SizedBox(height: AppConstants.space8),

          // Multi-Track Gantt Bars
          Container(
            padding: const EdgeInsets.all(AppConstants.space12),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : const Color(0xFF0C1322),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Track 1: Solar Illumination
                _buildTimelineTrack(
                  title: 'Solar Illumination',
                  icon: Icons.wb_sunny_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  totalHours: totalHours,
                  windows: windows,
                  colorExtractor: (w) => w.hasSunlight
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF1E293B),
                ),
                const SizedBox(height: AppConstants.space12),

                // Track 2: Direct Earth Comm
                _buildTimelineTrack(
                  title: 'Earth Line-of-Sight (DTE)',
                  icon: Icons.public_rounded,
                  iconColor: AppColors.darkPrimary,
                  totalHours: totalHours,
                  windows: windows,
                  colorExtractor: (w) => w.hasEarthLineOfSight
                      ? AppColors.darkPrimary
                      : const Color(0xFF1E293B),
                ),
                const SizedBox(height: AppConstants.space12),

                // Track 3: Composite Optimal Window
                _buildTimelineTrack(
                  title: 'Optimal Operations Window (Sun + Comm)',
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.statusSuccess,
                  totalHours: totalHours,
                  windows: windows,
                  colorExtractor: (w) =>
                      (w.hasSunlight && w.hasEarthLineOfSight)
                      ? AppColors.statusSuccess
                      : const Color(0xFF1E293B),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.space12),
          // Legend
          Wrap(
            spacing: AppConstants.space16,
            runSpacing: AppConstants.space4,
            children: [
              _buildLegendItem('Daylight Active', const Color(0xFFF59E0B)),
              _buildLegendItem('Earth Comm Active', AppColors.darkPrimary),
              _buildLegendItem('Optimal EVA Window', AppColors.statusSuccess),
              _buildLegendItem('Shadow / Occulted', const Color(0xFF334155)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTrack({
    required String title,
    required IconData icon,
    required Color iconColor,
    required double totalHours,
    required List<VisibilityTimeWindow> windows,
    required Color Function(VisibilityTimeWindow) colorExtractor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 14),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 18,
            child: Row(
              children: windows.map((w) {
                final flex = (w.durationHours / totalHours * 1000).round();
                return Expanded(
                  flex: math.max(1, flex),
                  child: Container(
                    color: colorExtractor(w),
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildInstantTelemetryCard(
    BuildContext context,
    CelestialVisibilityState state,
  ) {
    final currentInstant = _missionEpoch.add(
      Duration(milliseconds: (_currentTimeOffsetHours * 3600 * 1000).round()),
    );
    final instantStr =
        '${currentInstant.year}-${currentInstant.month.toString().padLeft(2, '0')}-${currentInstant.day.toString().padLeft(2, '0')} ${currentInstant.hour.toString().padLeft(2, '0')}:${currentInstant.minute.toString().padLeft(2, '0')} UTC';

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Instantaneous Conditions at $instantStr',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              StatusBadge(
                label:
                    state.illuminationState ==
                        SolarIlluminationState.directSunlight
                    ? 'DAYLIGHT'
                    : 'SHADOW',
                color:
                    state.illuminationState ==
                        SolarIlluminationState.directSunlight
                    ? AppColors.statusSuccess
                    : AppColors.statusError,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Sun Elevation',
                  '${state.sunElevationDegrees >= 0 ? '+' : ''}${state.sunElevationDegrees.toStringAsFixed(2)}°',
                  state.sunElevationDegrees >= 0
                      ? 'Above Horizon'
                      : 'Sub-Horizon',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Earth Elevation',
                  '${state.earthElevationDegrees >= 0 ? '+' : ''}${state.earthElevationDegrees.toStringAsFixed(2)}°',
                  state.earthElevationDegrees >= 0
                      ? 'Line-of-Sight'
                      : 'Occulted',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Comm Margin',
                  '+${state.commLinkMarginDb.toStringAsFixed(1)} dB',
                  'DSN DTE Link',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String title, String val, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.darkPrimary,
          ),
        ),
        Text(sub, style: const TextStyle(fontSize: 10, color: Colors.white54)),
      ],
    );
  }

  Widget _buildOperationalMilestonesCard(
    BuildContext context,
    double totalHours,
  ) {
    final theme = Theme.of(context);

    final milestones = [
      (
        'T+02:00h',
        'Lunar Descent & Touchdown',
        'Scheduled at initial illumination rise to minimize shadowing risks.',
        Icons.flight_land_rounded,
        AppColors.statusSuccess,
      ),
      (
        'T+24:00h',
        'EVA 1: Solar Array & Comms Deploy',
        'Deploy surface arrays and orient high-gain antenna to Earth.',
        Icons.solar_power_rounded,
        const Color(0xFFF59E0B),
      ),
      (
        'T+72:00h',
        'EVA 2: Crater Rim Geological Sampling',
        'High-priority core drilling in permanently shadowed crater flank.',
        Icons.science_rounded,
        AppColors.darkPrimary,
      ),
      (
        'T+120:00h',
        'Science Downlink & Instrument Telemetry',
        'Bulk transfer of multispectral imagery to Earth Mission Control.',
        Icons.satellite_alt_rounded,
        AppColors.darkSecondary,
      ),
      (
        'T+160:00h',
        'Surface Pre-Ascent Preparation',
        'Sample stowage, rover lock-down, and ascent vehicle propellant chill-down.',
        Icons.flight_takeoff_rounded,
        AppColors.statusWarning,
      ),
    ];

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.list_alt_rounded,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: AppConstants.space8),
              Text(
                'Planned Surface Operational Milestones',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Column(
            children: milestones.map((m) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: m.$5.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(m.$4, color: m.$5, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                m.$2,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                m.$1,
                                style: TextStyle(
                                  color: m.$5,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            m.$3,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerBudgetCard(
    BuildContext context,
    CelestialVisibilityState state,
  ) {
    final theme = Theme.of(context);
    final isLit =
        state.illuminationState == SolarIlluminationState.directSunlight;
    final solarPowerWatts = isLit
        ? 2500.0 * (state.solarFluxWattsPerM2 / 1361.0)
        : 0.0;
    const baseDemandWatts = 1200.0;
    final netPowerWatts = solarPowerWatts - baseDemandWatts;
    final batterySocPct = isLit ? 100.0 : 85.0;

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.battery_charging_full_rounded,
                color: AppColors.statusSuccess,
                size: 22,
              ),
              const SizedBox(width: AppConstants.space8),
              Text(
                'Lander Power & Thermal Simulation',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Solar Array Output',
                  '${solarPowerWatts.toStringAsFixed(0)} W',
                  '2.5 kW Nominal Array',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Net Power Balance',
                  '${netPowerWatts >= 0 ? '+' : ''}${netPowerWatts.toStringAsFixed(0)} W',
                  '${baseDemandWatts.toStringAsFixed(0)} W Habitat Load',
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Battery State of Charge',
                  '${batterySocPct.toStringAsFixed(0)}%',
                  'Li-ion Reserve Margin',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityPolicyCard(BuildContext context) {
    final theme = Theme.of(context);

    return ScientificCard(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.25,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColors.statusInfo),
          const SizedBox(width: AppConstants.space12),
          Expanded(
            child: Text(
              'Demonstration Mode Notice: Operational timeline intervals and celestial elevation angles are dynamically projected for mission planning demonstration using the verified LocalHorizonBasis topocentric SEZ triad, pending full offline JPL DE421 planetary ephemeris vector interpolation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
