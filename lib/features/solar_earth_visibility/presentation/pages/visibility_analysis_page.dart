import 'dart:async';
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

/// Interactive Solar Illumination and Earth Visibility Analysis Page.
///
/// Features a real-time local celestial sky dome visualizer, time scrubber simulation,
/// topocentric elevation/azimuth calculations, and Earth communication link telemetry.
class VisibilityAnalysisPage extends StatefulWidget {
  final LunarSite? initialSite;
  final LunarSiteRepository repository;
  final CelestialVisibilityService visibilityService;

  const VisibilityAnalysisPage({
    super.key,
    this.initialSite,
    required this.repository,
    this.visibilityService = const CelestialVisibilityService(),
  });

  @override
  State<VisibilityAnalysisPage> createState() => _VisibilityAnalysisPageState();
}

class _VisibilityAnalysisPageState extends State<VisibilityAnalysisPage> {
  final LunarMapCoordinatesHelper _coordsHelper =
      const LunarMapCoordinatesHelper();

  List<LunarSite> _sites = [];
  LunarSite? _selectedSite;
  bool _isLoading = true;

  // Time simulation state: elapsed hours across synodic cycle [0.0, 708.7]
  double _epochHours = 72.0; // 3 days into lunar day
  bool _isPlaying = false;
  Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
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
            (s) => s.siteCode == 'Site04', // Default Shackleton Rim
            orElse: () => allSites.first,
          );
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSimulation() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _simulationTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _epochHours =
              (_epochHours + 1.5) % CelestialVisibilityService.synodicDayHours;
        });
      });
    } else {
      _simulationTimer?.cancel();
    }
  }

  void _stepTime(double deltaHours) {
    setState(() {
      _epochHours = (_epochHours + deltaHours).clamp(
        0.0,
        CelestialVisibilityService.synodicDayHours,
      );
    });
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

    final visibilityState = widget.visibilityService.computeVisibility(
      latitudeDeg: lat,
      longitudeDeg: lon,
      epochHours: _epochHours,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solar & Earth Visibility'),
        actions: [
          IconButton(
            tooltip: 'Reset to New Moon Epoch',
            icon: const Icon(Icons.restart_alt_rounded),
            onPressed: () => setState(() => _epochHours = 0.0),
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
                // 1. Site Selector Bar
                _buildSiteSelectorCard(context),
                const SizedBox(height: AppConstants.space16),

                // 2. Interactive Celestial Sky Dome Visualizer
                _buildSkyDomeVisualizer(context, visibilityState, lat, lon),
                const SizedBox(height: AppConstants.space16),

                // 3. Time Scrubber & Simulation Controls
                _buildTimeControlsCard(context),
                const SizedBox(height: AppConstants.space20),

                // 4. Primary Telemetry Panels (Solar + Earth)
                if (isCompact) ...[
                  _buildSolarTelemetryCard(context, visibilityState),
                  const SizedBox(height: AppConstants.space16),
                  _buildEarthTelemetryCard(context, visibilityState),
                ] else ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildSolarTelemetryCard(
                          context,
                          visibilityState,
                        ),
                      ),
                      const SizedBox(width: AppConstants.space16),
                      Expanded(
                        child: _buildEarthTelemetryCard(
                          context,
                          visibilityState,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppConstants.space20),

                // 5. Mathematical Domain Engine Verification Card
                _buildEngineVerificationCard(context, visibilityState),
                const SizedBox(height: AppConstants.space24),

                // 6. Navigation to Mission Time Planner
                Center(
                  child: FilledButton.icon(
                    onPressed: () {
                      if (_selectedSite != null) {
                        Navigator.of(context)
                            .pushNamed('/planner', arguments: _selectedSite);
                      }
                    },
                    icon: const Icon(Icons.access_time_rounded),
                    label: const Text(
                      'Open Mission Time Planner for this Site',
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

  Widget _buildSiteSelectorCard(BuildContext context) {
    final theme = Theme.of(context);

    return ScientificCard(
      child: Row(
        children: [
          Icon(
            Icons.location_on_rounded,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: AppConstants.space12),
          Text(
            'Target Site:',
            style: theme.textTheme.titleMedium?.copyWith(
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
                      _selectedSite = _sites.firstWhere((s) => s.id == newId);
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkyDomeVisualizer(
    BuildContext context,
    CelestialVisibilityState state,
    double lat,
    double lon,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: Container(
        height: 320,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : const Color(0xFF070B14),
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Stack(
          children: [
            // Celestial Custom Painter
            CustomPaint(
              size: const Size(double.infinity, 320),
              painter: _CelestialSkyDomePainter(
                visibilityState: state,
                primaryColor: theme.colorScheme.primary,
              ),
            ),

            // Top Status Overlay
            Positioned(
              top: 12,
              left: 14,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.25,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'LOCAL HORIZON SKY DOME (SEZ FRAME)',
                          style: TextStyle(
                            color: AppColors.darkPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Celestial Body Coordinates Overlay
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Sun Telemetry Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wb_sunny_rounded,
                          color: Color(0xFFF59E0B),
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Sun: El ${state.sunElevationDegrees >= 0 ? '+' : ''}${state.sunElevationDegrees.toStringAsFixed(2)}° | Az ${state.sunAzimuthDegrees.toStringAsFixed(1)}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Earth Telemetry Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.darkPrimary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.public_rounded,
                          color: AppColors.darkPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Earth: El ${state.earthElevationDegrees >= 0 ? '+' : ''}${state.earthElevationDegrees.toStringAsFixed(2)}° | Az ${state.earthAzimuthDegrees.toStringAsFixed(1)}°',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeControlsCard(BuildContext context) {
    final theme = Theme.of(context);
    final elapsedDays = (_epochHours / 24.0).toStringAsFixed(1);
    final synodicPct =
        ((_epochHours / CelestialVisibilityService.synodicDayHours) * 100)
            .toStringAsFixed(1);

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.space8),
                  Text(
                    'Lunar Synodic Timeline Scrubber',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                'Day $elapsedDays of 29.5 ($synodicPct%)',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.darkPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space8),

          // Slider
          Slider(
            value: _epochHours,
            min: 0.0,
            max: CelestialVisibilityService.synodicDayHours,
            divisions: 200,
            label: '${_epochHours.toStringAsFixed(1)}h',
            onChanged: (newVal) {
              setState(() {
                _epochHours = newVal;
              });
            },
          ),

          // Interactive Control Buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  tooltip: '-24 Hours',
                  icon: const Icon(Icons.replay_10_rounded),
                  onPressed: () => _stepTime(-24.0),
                ),
                const SizedBox(width: AppConstants.space8),
                IconButton.outlined(
                  tooltip: '-6 Hours',
                  icon: const Icon(Icons.fast_rewind_rounded),
                  onPressed: () => _stepTime(-6.0),
                ),
                const SizedBox(width: AppConstants.space12),
                FilledButton.icon(
                  onPressed: _toggleSimulation,
                  icon: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(_isPlaying ? 'Pause' : 'Simulate'),
                ),
                const SizedBox(width: AppConstants.space12),
                IconButton.outlined(
                  tooltip: '+6 Hours',
                  icon: const Icon(Icons.fast_forward_rounded),
                  onPressed: () => _stepTime(6.0),
                ),
                const SizedBox(width: AppConstants.space8),
                IconButton.outlined(
                  tooltip: '+24 Hours',
                  icon: const Icon(Icons.forward_10_rounded),
                  onPressed: () => _stepTime(24.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSolarTelemetryCard(
    BuildContext context,
    CelestialVisibilityState state,
  ) {
    final theme = Theme.of(context);
    final (
      statusLabel,
      statusColor,
      statusIcon,
    ) = switch (state.illuminationState) {
      SolarIlluminationState.directSunlight => (
        'DIRECT SUNLIGHT ACTIVE',
        AppColors.statusSuccess,
        Icons.wb_sunny_rounded,
      ),
      SolarIlluminationState.grazingTwilight => (
        'GRAZING TWILIGHT (PENUMBRA)',
        AppColors.statusWarning,
        Icons.wb_twilight_rounded,
      ),
      SolarIlluminationState.totalShadow => (
        'TOTAL SHADOW / NIGHT',
        AppColors.statusError,
        Icons.nightlight_round,
      ),
    };

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.solar_power_rounded,
                color: const Color(0xFFF59E0B),
                size: 22,
              ),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: Text(
                  'Solar Illumination Status',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.space16),
          _buildMetricRow(
            context,
            'Sun Elevation Angle',
            '${state.sunElevationDegrees >= 0 ? '+' : ''}${state.sunElevationDegrees.toStringAsFixed(3)}°',
            state.sunElevationDegrees >= 0 ? 'Above horizon' : 'Below horizon',
          ),
          const Divider(height: AppConstants.space16),
          _buildMetricRow(
            context,
            'Sun Azimuth Angle (from S)',
            '${state.sunAzimuthDegrees.toStringAsFixed(2)}°',
            'Measured clockwise in SEZ triad',
          ),
          const Divider(height: AppConstants.space16),
          _buildMetricRow(
            context,
            'Incident Solar Flux',
            '${state.solarFluxWattsPerM2.toStringAsFixed(1)} W/m²',
            'Nominal top-of-surface irradiance',
          ),
        ],
      ),
    );
  }

  Widget _buildEarthTelemetryCard(
    BuildContext context,
    CelestialVisibilityState state,
  ) {
    final theme = Theme.of(context);
    final (
      statusLabel,
      statusColor,
      statusIcon,
    ) = switch (state.earthVisibilityState) {
      EarthVisibilityState.directLineOfSight => (
        'DIRECT LINE OF SIGHT (DTE)',
        AppColors.statusSuccess,
        Icons.satellite_alt_rounded,
      ),
      EarthVisibilityState.marginalVisibility => (
        'MARGINAL GRAZING LOS',
        AppColors.statusWarning,
        Icons.wifi_channel_rounded,
      ),
      EarthVisibilityState.occulted => (
        'OCCULTED BY TERRAIN / HORIZON',
        AppColors.statusError,
        Icons.signal_cellular_off_rounded,
      ),
    };

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.public_rounded,
                color: AppColors.darkPrimary,
                size: 22,
              ),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: Text(
                  'Earth Visibility & Comm Link',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.space16),
          _buildMetricRow(
            context,
            'Earth Elevation Angle',
            '${state.earthElevationDegrees >= 0 ? '+' : ''}${state.earthElevationDegrees.toStringAsFixed(3)}°',
            state.earthElevationDegrees >= 0
                ? 'Clear line of sight'
                : 'Occulted by lunar limb',
          ),
          const Divider(height: AppConstants.space16),
          _buildMetricRow(
            context,
            'Earth Azimuth Angle (from S)',
            '${state.earthAzimuthDegrees.toStringAsFixed(2)}°',
            'Hovering near 0° prime meridian',
          ),
          const Divider(height: AppConstants.space16),
          _buildMetricRow(
            context,
            'Direct-to-Earth Comm Margin',
            '+${state.commLinkMarginDb.toStringAsFixed(1)} dB',
            'Deep Space Network (DSN) link',
          ),
        ],
      ),
    );
  }

  Widget _buildEngineVerificationCard(
    BuildContext context,
    CelestialVisibilityState state,
  ) {
    final theme = Theme.of(context);
    final uS = state.horizonBasis.south;
    final uE = state.horizonBasis.east;
    final uZ = state.horizonBasis.zenith;

    return ScientificCard(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.25,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_outlined,
                color: AppColors.statusSuccess,
                size: 20,
              ),
              const SizedBox(width: AppConstants.space8),
              Text(
                'Scientific Domain Engine Integration',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const StatusBadge(
                label: 'PHASE 06 M03 ACTIVE',
                color: AppColors.statusSuccess,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            'Evaluated via LocalHorizonBasis orthonormal SEZ triad and AstronomicalTime TT/TDB engine:',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppConstants.space8),
          Container(
            padding: const EdgeInsets.all(AppConstants.space12),
            decoration: BoxDecoration(
              color: AppColors.darkBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.darkBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'uS (South):  [${uS.x.toStringAsFixed(6)}, ${uS.y.toStringAsFixed(6)}, ${uS.z.toStringAsFixed(6)}]',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.darkPrimary,
                  ),
                ),
                Text(
                  'uE (East):   [${uE.x.toStringAsFixed(6)}, ${uE.y.toStringAsFixed(6)}, ${uE.z.toStringAsFixed(6)}]',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.darkPrimary,
                  ),
                ),
                Text(
                  'uZ (Zenith): [${uZ.x.toStringAsFixed(6)}, ${uZ.y.toStringAsFixed(6)}, ${uZ.z.toStringAsFixed(6)}]',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.darkPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.space12),
          Row(
            children: [
              Icon(Icons.info_outline, size: 14, color: AppColors.statusInfo),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Demonstration Ephemeris Mode: Dynamic polar trigonometric projection pending full offline JPL DE421 ephemeris vector interpolation.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
    String helper,
  ) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium),
              Text(
                helper,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppConstants.space8),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.darkPrimary,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter rendering the panoramic local horizon dome with Sun and Earth markers.
class _CelestialSkyDomePainter extends CustomPainter {
  final CelestialVisibilityState visibilityState;
  final Color primaryColor;

  _CelestialSkyDomePainter({
    required this.visibilityState,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizonY = h * 0.65; // Local horizon line at 65% height

    // 1. Sky & Ground Gradient
    final skyRect = Rect.fromLTWH(0, 0, w, horizonY);
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF030712), Color(0xFF091428)],
      ).createShader(skyRect);
    canvas.drawRect(skyRect, skyPaint);

    final groundRect = Rect.fromLTWH(0, horizonY, w, h - horizonY);
    final groundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
      ).createShader(groundRect);
    canvas.drawRect(groundRect, groundPaint);

    // 2. Stars in the background
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    final random = math.Random(42);
    for (int i = 0; i < 40; i++) {
      final sx = random.nextDouble() * w;
      final sy = random.nextDouble() * (horizonY - 10);
      canvas.drawCircle(
        Offset(sx, sy),
        0.8 + random.nextDouble() * 0.8,
        starPaint,
      );
    }

    // 3. Horizon Grid Lines (+10°, +20°, -5°)
    final gridPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Scale: 10 degrees elevation = 50 pixels
    const double pxPerDeg = 5.0;

    for (final deg in [10.0, 20.0]) {
      final y = horizonY - deg * pxPerDeg;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '+${deg.toInt()}°',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(8, y - 10));
    }

    // 4. Horizon Line (0°)
    final horizonPaint = Paint()
      ..color = AppColors.darkPrimary.withValues(alpha: 0.6)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, horizonY), Offset(w, horizonY), horizonPaint);

    final htp = TextPainter(
      text: const TextSpan(
        text: '0° HORIZON',
        style: TextStyle(
          color: AppColors.darkPrimary,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    htp.paint(canvas, Offset(8, horizonY + 4));

    // 5. Cardinal Direction Labels (S: 0°, E: 90°, N: 180°, W: 270°, S: 360°)
    final cardinalPoints = [
      (0.0, 'S (0°)'),
      (90.0, 'E (90°)'),
      (180.0, 'N (180°)'),
      (270.0, 'W (270°)'),
      (360.0, 'S (360°)'),
    ];

    for (final cp in cardinalPoints) {
      final az = cp.$1;
      final label = cp.$2;
      final x = (az / 360.0) * w;
      canvas.drawLine(
        Offset(x, horizonY - 4),
        Offset(x, horizonY + 4),
        horizonPaint,
      );

      final cpTp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      cpTp.paint(canvas, Offset(x - cpTp.width / 2, horizonY + 6));
    }

    // 6. Draw Sun
    final sunAz = visibilityState.sunAzimuthDegrees;
    final sunElev = visibilityState.sunElevationDegrees;
    final sunX = (sunAz / 360.0) * w;
    final sunY = horizonY - sunElev * pxPerDeg;

    // Solar Corona & Radiant Rays
    final sunHaloPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(sunX, sunY), 24, sunHaloPaint);

    final sunCorePaint = Paint()
      ..color = const Color(0xFFFDE047)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(sunX, sunY), 10, sunCorePaint);

    // Sun label
    final sunTp = TextPainter(
      text: TextSpan(
        text: 'SUN (${sunElev >= 0 ? '+' : ''}${sunElev.toStringAsFixed(1)}°)',
        style: const TextStyle(
          color: Color(0xFFFDE047),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sunTp.paint(canvas, Offset(sunX - sunTp.width / 2, sunY - 24));

    // 7. Draw Earth
    final earthAz = visibilityState.earthAzimuthDegrees;
    final earthElev = visibilityState.earthElevationDegrees;
    final earthX = (earthAz / 360.0) * w;
    final earthY = horizonY - earthElev * pxPerDeg;

    final earthHaloPaint = Paint()
      ..color = AppColors.darkPrimary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(earthX, earthY), 20, earthHaloPaint);

    final earthCorePaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(earthX, earthY), 8, earthCorePaint);

    // Earth continent detail
    final continentPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(earthX - 2, earthY - 1), 3.5, continentPaint);

    // Earth label
    final earthTp = TextPainter(
      text: TextSpan(
        text:
            'EARTH (${earthElev >= 0 ? '+' : ''}${earthElev.toStringAsFixed(1)}°)',
        style: const TextStyle(
          color: AppColors.darkPrimary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    earthTp.paint(canvas, Offset(earthX - earthTp.width / 2, earthY - 22));
  }

  @override
  bool shouldRepaint(covariant _CelestialSkyDomePainter oldDelegate) {
    return oldDelegate.visibilityState.sunElevationDegrees !=
            visibilityState.sunElevationDegrees ||
        oldDelegate.visibilityState.sunAzimuthDegrees !=
            visibilityState.sunAzimuthDegrees ||
        oldDelegate.visibilityState.earthElevationDegrees !=
            visibilityState.earthElevationDegrees;
  }
}
