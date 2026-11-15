import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/repositories/lunar_site_repository.dart';
import 'package:luna_sight/features/lunar_sites/domain/services/lunar_map_coordinates_helper.dart';

/// Interactive Lunar South Polar Stereographic Map.
///
/// Projects landing sites and prominent craters onto a stereographic polar chart
/// centered at 90°S. Supports tapping ANY location to convert screen coordinates
/// into valid selenographic latitude and longitude, inspecting real-time solar
/// and Earth visibility, and saving persistent custom landing sites.
class LunarPolarMapWidget extends StatefulWidget {
  final List<LunarSite> sites;
  final LunarSite? selectedSite;
  final LunarSiteRepository? repository;
  final ValueChanged<LunarSite>? onSiteSelected;
  final ValueChanged<SelectedLunarLocation>? onLocationSelected;
  final ValueChanged<LunarSite>? onSiteSaved;
  final void Function(LunarSite)? onOpenDetails;
  final void Function(LunarSite)? onOpenVisibility;
  final void Function(LunarSite)? onOpenPlanner;

  final bool enablePulseAnimation;

  const LunarPolarMapWidget({
    super.key,
    required this.sites,
    this.selectedSite,
    this.repository,
    this.enablePulseAnimation = false,
    this.onSiteSelected,
    this.onLocationSelected,
    this.onSiteSaved,
    this.onOpenDetails,
    this.onOpenVisibility,
    this.onOpenPlanner,
  });

  @override
  State<LunarPolarMapWidget> createState() => _LunarPolarMapWidgetState();
}

class _LunarPolarMapWidgetState extends State<LunarPolarMapWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  final LunarMapCoordinatesHelper _coordsHelper =
      const LunarMapCoordinatesHelper();

  LunarSite? _internalSelectedSite;
  SelectedLunarLocation? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _internalSelectedSite =
        widget.selectedSite ??
        (widget.sites.isNotEmpty ? widget.sites.first : null);

    if (_internalSelectedSite != null) {
      final pt = _coordsHelper.getMapPoint(_internalSelectedSite!);
      if (pt != null) {
        _selectedLocation = _coordsHelper.evaluateSelectedLocation(
          latitude: pt.latitude,
          longitude: pt.longitude,
          existingSites: widget.sites,
        );
      }
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: 0.5,
    );
    if (widget.enablePulseAnimation) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant LunarPolarMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSite != null &&
        widget.selectedSite != _internalSelectedSite) {
      setState(() {
        _internalSelectedSite = widget.selectedSite;
        final pt = _coordsHelper.getMapPoint(widget.selectedSite!);
        if (pt != null) {
          _selectedLocation = _coordsHelper.evaluateSelectedLocation(
            latitude: pt.latitude,
            longitude: pt.longitude,
            existingSites: widget.sites,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTapOnMap(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final mapRadius = math.min(size.width, size.height) * 0.44;

    // 1. Check if tap is on or very close to an existing site marker (threshold 28px)
    LunarSite? closestSite;
    double minSiteDistance = double.infinity;

    for (final site in widget.sites) {
      final point = _coordsHelper.getMapPoint(site);
      if (point == null) continue;

      final r = point.normalizedRadius * mapRadius;
      final angle = point.polarAngleRadians;
      final markerX = center.dx + r * math.sin(angle);
      final markerY = center.dy - r * math.cos(angle);

      final distance = (Offset(markerX, markerY) - localPosition).distance;
      if (distance < minSiteDistance) {
        minSiteDistance = distance;
        closestSite = site;
      }
    }

    if (closestSite != null && minSiteDistance < 28.0) {
      final pt = _coordsHelper.getMapPoint(closestSite)!;
      final evaluated = _coordsHelper.evaluateSelectedLocation(
        latitude: pt.latitude,
        longitude: pt.longitude,
        existingSites: widget.sites,
      );

      setState(() {
        _internalSelectedSite = closestSite;
        _selectedLocation = evaluated;
      });

      widget.onSiteSelected?.call(closestSite);
      widget.onLocationSelected?.call(evaluated);
      return;
    }

    // 2. Otherwise, convert tapped screen coordinates into selenographic (lat, lon)
    final (lat, lon) = _coordsHelper.screenOffsetToCoordinates(
      localPosition,
      size,
    );

    final evaluated = _coordsHelper.evaluateSelectedLocation(
      latitude: lat,
      longitude: lon,
      existingSites: widget.sites,
    );

    setState(() {
      _selectedLocation = evaluated;
      _internalSelectedSite = evaluated.isNearExistingSite
          ? evaluated.existingSite
          : null;
    });

    widget.onLocationSelected?.call(evaluated);
    if (evaluated.isNearExistingSite && evaluated.existingSite != null) {
      widget.onSiteSelected?.call(evaluated.existingSite!);
    }
  }

  void _showSaveSiteDialog(BuildContext context, SelectedLunarLocation loc) {
    final nameController = TextEditingController(
      text: 'Site near ${loc.nearestLandmark.landmark.name}',
    );
    final descController = TextEditingController(
      text:
          'Manual operator selection at ${loc.formattedLatitude}, ${loc.formattedLongitudeEast} (${loc.distanceToSouthPoleKm.toStringAsFixed(1)} km from 90°S).',
    );
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? dialogError;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final theme = Theme.of(context);

            return Padding(
              padding: EdgeInsets.only(
                left: AppConstants.space20,
                right: AppConstants.space20,
                top: AppConstants.space20,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    AppConstants.space24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bookmark_add_rounded,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                          const SizedBox(width: AppConstants.space8),
                          Expanded(
                            child: Text(
                              'Save Custom Landing Site',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.space12),

                      if (dialogError != null) ...[
                        Container(
                          padding: const EdgeInsets.all(AppConstants.space12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusMedium,
                            ),
                          ),
                          child: Text(
                            dialogError!,
                            style: TextStyle(
                              color: theme.colorScheme.onErrorContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.space12),
                      ],

                      // Readonly Selenographic Coordinates Card
                      Container(
                        padding: const EdgeInsets.all(AppConstants.space12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selenographic Coordinates',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${loc.formattedLatitude}, ${loc.formattedLongitudeEast}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            StatusBadge(
                              label:
                                  '${loc.distanceToSouthPoleKm.toStringAsFixed(1)} km to Pole',
                              color: AppColors.statusInfo,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.space16),

                      // Editable Site Name with duplicate validation
                      TextFormField(
                        key: const Key('custom_site_name_input'),
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Landing Site Name *',
                          hintText: 'e.g., Artemis III Candidate Alpha',
                          prefixIcon: Icon(Icons.label_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Site name is required';
                          }
                          final trimmed = value.trim().toLowerCase();
                          final isDuplicate = widget.sites.any(
                            (s) => s.name.trim().toLowerCase() == trimmed,
                          );
                          if (isDuplicate) {
                            return 'A site with this name already exists. Choose a distinct name.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppConstants.space16),

                      // Optional Description
                      TextFormField(
                        key: const Key('custom_site_desc_input'),
                        controller: descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Mission Description',
                          hintText: 'Operational objectives, traverse goals...',
                          prefixIcon: Icon(Icons.notes_rounded),
                        ),
                      ),
                      const SizedBox(height: AppConstants.space20),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: AppConstants.space12),
                          FilledButton.icon(
                            key: const Key('confirm_save_custom_site_button'),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) {
                                      return;
                                    }
                                    setModalState(() {
                                      isSaving = true;
                                      dialogError = null;
                                    });

                                    try {
                                      final repo = widget.repository;
                                      if (repo == null) {
                                        throw StateError(
                                          'Repository not attached.',
                                        );
                                      }

                                      final coords = LunarCoordinates(
                                        latitude: loc.latitude,
                                        longitude: loc.longitude,
                                        longitudeConvention:
                                            LongitudeConvention.eastPositive,
                                        provenance:
                                            CoordinateProvenance.userEntered,
                                      );

                                      final savedSite = await repo
                                          .addCustomSite(
                                            name: nameController.text.trim(),
                                            coordinates: coords,
                                            description: descController.text
                                                .trim(),
                                          );

                                      if (!context.mounted) return;
                                      Navigator.of(context).pop();

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Custom landing site "${savedSite.name}" registered successfully!',
                                          ),
                                          backgroundColor:
                                              AppColors.statusSuccess,
                                        ),
                                      );

                                      setState(() {
                                        _internalSelectedSite = savedSite;
                                      });

                                      widget.onSiteSaved?.call(savedSite);
                                      widget.onSiteSelected?.call(savedSite);
                                    } catch (e) {
                                      setModalState(() {
                                        isSaving = false;
                                        dialogError = '$e';
                                      });
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Save Landing Site'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loc = _selectedLocation;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Interactive Polar Canvas
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          child: Container(
            height: 340,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : const Color(0xFF0C1322),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Custom Painter for Map Grid, Craters, Markers, and Selection Crosshair
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          key: const Key('lunar_polar_map_gesture_detector'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {},
                          onTapDown: (details) => _handleTapOnMap(
                            details.localPosition,
                            Size(constraints.maxWidth, constraints.maxHeight),
                          ),
                          child: CustomPaint(
                            key: const Key('lunar_polar_map_canvas'),
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            painter: _PolarStereographicPainter(
                              sites: widget.sites,
                              selectedSite: _internalSelectedSite,
                              selectedLocation: loc,
                              coordsHelper: _coordsHelper,
                              pulseValue: _pulseController.value,
                              primaryColor: theme.colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),

                // Top Map HUD Overlays
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.radar_rounded,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LUNAR SOUTH POLE 90°S',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.darkPrimary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Legend / Projection Indicator
                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.darkSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '80°S - 90°S Stereographic (Tap to Select)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.darkTextTertiary,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

                // Cardinal Label: 0° Longitude (Earth-Facing / Prime Meridian)
                Positioned(
                  top: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      '0° E (Earth-Facing)',
                      style: TextStyle(
                        color: AppColors.darkPrimary.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // 180° (Far Side)
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      '180° E (Far Side)',
                      style: TextStyle(
                        color: AppColors.darkTextTertiary.withValues(
                          alpha: 0.7,
                        ),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppConstants.space12),

        // Selected Location Details & Registration Card
        if (loc != null) _buildSelectedLocationCard(context, loc),
      ],
    );
  }

  Widget _buildSelectedLocationCard(
    BuildContext context,
    SelectedLunarLocation loc,
  ) {
    final theme = Theme.of(context);
    final isCustom =
        _internalSelectedSite?.classification == SiteClassification.userDefined;

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Location Badge and Name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _internalSelectedSite != null
                          ? _internalSelectedSite!.name
                          : 'Target Selenographic Location',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Selenographic Coordinates: ${loc.formattedLatitude}, ${loc.formattedLongitudeEast} • ${loc.distanceToSouthPoleKm.toStringAsFixed(1)} km from 90°S',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.darkPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label: _internalSelectedSite != null
                    ? (_internalSelectedSite!.classification ==
                              SiteClassification.userDefined
                          ? 'USER SAVED'
                          : 'CATALOG')
                    : 'NEW TARGET',
                color: _internalSelectedSite != null
                    ? (_internalSelectedSite!.classification ==
                              SiteClassification.userDefined
                          ? AppColors.statusSuccess
                          : AppColors.statusInfo)
                    : const Color(0xFFF59E0B),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.space12),

          // Nearest Known Landmark
          Row(
            children: [
              const Icon(
                Icons.landscape_rounded,
                size: 16,
                color: AppColors.darkTextSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Nearest Landmark: ${loc.nearestLandmark.formattedSummary}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.space8),

          // Available Elevation and Terrain Information
          Container(
            padding: const EdgeInsets.all(AppConstants.space12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.terrain_rounded,
                      size: 14,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Terrain & Elevation Data Status',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Source: ${loc.terrainStatus.sourceName} (${loc.terrainStatus.resolution})',
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                Text(
                  'Datum: ${loc.terrainStatus.datumDescription}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  loc.terrainStatus.measurementNotice,
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppConstants.space8),

          // Solar & Earth Topocentric Visibility
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.wb_sunny_rounded,
                            size: 12,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sun Elevation',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${loc.visibility.sunElevationDegrees >= 0 ? "+" : ""}${loc.visibility.sunElevationDegrees.toStringAsFixed(2)}° (${loc.visibility.illuminationState.name})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.space8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.darkPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.darkPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.public_rounded,
                            size: 12,
                            color: AppColors.darkPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Earth Elevation',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${loc.visibility.earthElevationDegrees >= 0 ? "+" : ""}${loc.visibility.earthElevationDegrees.toStringAsFixed(2)}° (${loc.visibility.commLinkMarginDb > 0 ? "+${loc.visibility.commLinkMarginDb.toStringAsFixed(1)} dB" : "No LOS"})',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.space12),
          const Divider(height: 1),
          const SizedBox(height: AppConstants.space12),

          // Action Buttons
          Wrap(
            spacing: AppConstants.space8,
            runSpacing: AppConstants.space8,
            children: [
              // Save as Custom Site Button (shown if not an already saved site)
              if (!isCustom)
                FilledButton.icon(
                  key: const Key('save_selected_location_button'),
                  onPressed: () => _showSaveSiteDialog(context, loc),
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                  label: const Text('Save Custom Landing Site'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),

              // If an existing site is selected, allow viewing its profile
              if (_internalSelectedSite != null)
                FilledButton.tonalIcon(
                  onPressed: () =>
                      widget.onOpenDetails?.call(_internalSelectedSite!),
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Site Profile'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),

              OutlinedButton.icon(
                onPressed: () {
                  final siteToOpen =
                      _internalSelectedSite ??
                      LunarSite(
                        id: 'target_loc',
                        name: 'Selected Target',
                        siteCode: 'TARGET',
                        classification: SiteClassification.userDefined,
                        coordinates: LunarCoordinates(
                          latitude: loc.latitude,
                          longitude: loc.longitude,
                        ),
                        sourceId: 'TARGET',
                        sourceOrganization: 'User Target',
                        citation: 'Targeted polar coordinate',
                        description: 'Custom coordinates on lunar south pole.',
                      );
                  widget.onOpenVisibility?.call(siteToOpen);
                },
                icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                label: const Text('Visibility Analysis'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),

              OutlinedButton.icon(
                onPressed: () {
                  final siteToOpen =
                      _internalSelectedSite ??
                      LunarSite(
                        id: 'target_loc',
                        name: 'Selected Target',
                        siteCode: 'TARGET',
                        classification: SiteClassification.userDefined,
                        coordinates: LunarCoordinates(
                          latitude: loc.latitude,
                          longitude: loc.longitude,
                        ),
                        sourceId: 'TARGET',
                        sourceOrganization: 'User Target',
                        citation: 'Targeted polar coordinate',
                        description: 'Custom coordinates on lunar south pole.',
                      );
                  widget.onOpenPlanner?.call(siteToOpen);
                },
                icon: const Icon(Icons.access_time_rounded, size: 16),
                label: const Text('Time Planner'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// CustomPainter rendering the polar stereographic grid, major craters, site markers,
/// and the active target selection crosshair marker.
class _PolarStereographicPainter extends CustomPainter {
  final List<LunarSite> sites;
  final LunarSite? selectedSite;
  final SelectedLunarLocation? selectedLocation;
  final LunarMapCoordinatesHelper coordsHelper;
  final double pulseValue;
  final Color primaryColor;

  _PolarStereographicPainter({
    required this.sites,
    required this.selectedSite,
    required this.selectedLocation,
    required this.coordsHelper,
    required this.pulseValue,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final mapRadius = math.min(size.width, size.height) * 0.44;

    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final axisPaint = Paint()
      ..color = const Color(0xFF334155).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 1. Draw Concentric Latitude Circles (80°S, 84°S, 87°S, 89°S)
    final latitudes = [80.0, 84.0, 87.0, 89.0];
    for (final lat in latitudes) {
      final normR = ((90.0 - lat) / 10.0).clamp(0.0, 1.0);
      final r = normR * mapRadius;
      canvas.drawCircle(center, r, gridPaint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${lat.toInt()}°S',
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(center.dx + 4, center.dy + r - 10));
    }

    // 2. Draw Meridian Spokes (0°, 90°, 180°, 270°)
    canvas.drawLine(
      Offset(center.dx, center.dy - mapRadius),
      Offset(center.dx, center.dy + mapRadius),
      axisPaint,
    );
    canvas.drawLine(
      Offset(center.dx - mapRadius, center.dy),
      Offset(center.dx + mapRadius, center.dy),
      axisPaint,
    );

    // 3. Draw Major South Pole Craters
    _drawProminentCraters(canvas, center, mapRadius);

    // 4. Draw South Pole Center Marker (90°S)
    final polePaint = Paint()
      ..color = AppColors.darkPrimary.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, polePaint);

    // 5. Draw Landing Site Markers
    for (final site in sites) {
      final isSelected = site.id == selectedSite?.id;
      final point = coordsHelper.getMapPoint(site);
      if (point == null) continue;

      final r = point.normalizedRadius * mapRadius;
      final angle = point.polarAngleRadians;
      final markerX = center.dx + r * math.sin(angle);
      final markerY = center.dy - r * math.cos(angle);
      final markerPos = Offset(markerX, markerY);

      final Color markerColor = switch (site.classification) {
        SiteClassification.highPriorityLandingSiteRegion =>
          AppColors.darkPrimary,
        SiteClassification.nasaCatalogRegion => AppColors.darkSecondary,
        SiteClassification.userDefined => AppColors.statusSuccess,
      };

      if (isSelected) {
        final haloPaint = Paint()
          ..color = markerColor.withValues(alpha: 0.3 * (1.0 - pulseValue))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(markerPos, 14.0 + pulseValue * 10.0, haloPaint);

        final ringPaint = Paint()
          ..color = markerColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(markerPos, 9.0, ringPaint);
      }

      final corePaint = Paint()
        ..color = isSelected ? Colors.white : markerColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(markerPos, isSelected ? 4.5 : 3.0, corePaint);

      if (isSelected ||
          site.classification ==
              SiteClassification.highPriorityLandingSiteRegion) {
        final labelPainter = TextPainter(
          text: TextSpan(
            text: site.siteCode,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : markerColor.withValues(alpha: 0.8),
              fontSize: isSelected ? 10 : 8,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        labelPainter.paint(canvas, Offset(markerX + 6, markerY - 6));
      }
    }

    // 6. Draw Arbitrary Selection Reticle / Crosshairs if a location is selected
    if (selectedLocation != null) {
      final loc = selectedLocation!;
      final deltaLat = (loc.latitude - (-90.0)).abs();
      final normR = (deltaLat / 10.0).clamp(0.0, 1.0);
      final r = normR * mapRadius;
      final angle = loc.longitude * math.pi / 180.0;
      final selX = center.dx + r * math.sin(angle);
      final selY = center.dy - r * math.cos(angle);
      final selPos = Offset(selX, selY);

      const selColor = Color(0xFFF59E0B); // Glowing Amber Reticle

      // Pulsing outer target circle
      final selPulsePaint = Paint()
        ..color = selColor.withValues(alpha: 0.25 * (1.0 - pulseValue))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPos, 18.0 + (pulseValue * 12.0), selPulsePaint);

      final selRingPaint = Paint()
        ..color = selColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(selPos, 10.0, selRingPaint);

      // Target Crosshairs
      final crosshairPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(selPos.dx - 16, selPos.dy),
        Offset(selPos.dx + 16, selPos.dy),
        crosshairPaint,
      );
      canvas.drawLine(
        Offset(selPos.dx, selPos.dy - 16),
        Offset(selPos.dx, selPos.dy + 16),
        crosshairPaint,
      );

      // Center dot
      final selDotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPos, 3.0, selDotPaint);
    }
  }

  void _drawProminentCraters(Canvas canvas, Offset center, double mapRadius) {
    const craters = [
      (-89.9, 0.0, 21.0, 'Shackleton'),
      (-87.3, 77.0, 39.0, 'Faustini'),
      (-88.1, 44.9, 51.0, 'Shoemaker'),
      (-87.4, 354.9, 35.0, 'Haworth'),
      (-88.5, 271.0, 32.0, 'de Gerlache'),
      (-85.2, 53.5, 73.0, 'Nobile'),
      (-84.5, 82.8, 101.0, 'Amundsen'),
      (-85.9, 2.9, 45.0, 'Malapert'),
    ];

    final craterRimPaint = Paint()
      ..color = const Color(0xFF1E293B).withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final craterFloorPaint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    for (final c in craters) {
      final lat = c.$1;
      final lon = c.$2;
      final diameterKm = c.$3;

      final deltaLat = (lat - (-90.0)).abs();
      final normR = (deltaLat / 10.0).clamp(0.0, 1.0);
      final r = normR * mapRadius;
      final angle = lon * math.pi / 180.0;

      final cx = center.dx + r * math.sin(angle);
      final cy = center.dy - r * math.cos(angle);
      final craterCenter = Offset(cx, cy);

      final radiusPx = (diameterKm / 606.0) * mapRadius;

      canvas.drawCircle(
        craterCenter,
        math.max(4.0, radiusPx),
        craterFloorPaint,
      );
      canvas.drawCircle(craterCenter, math.max(4.0, radiusPx), craterRimPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PolarStereographicPainter oldDelegate) {
    return oldDelegate.selectedSite != selectedSite ||
        oldDelegate.selectedLocation != selectedLocation ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.sites.length != sites.length;
  }
}
