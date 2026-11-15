import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:luna_sight/app/theme/app_colors.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/core/widgets/status_badge.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_site.dart';
import 'package:luna_sight/features/lunar_sites/domain/services/lunar_map_coordinates_helper.dart';

/// Interactive Lunar South Polar Stereographic Map.
///
/// Projects landing sites and prominent craters onto a stereographic polar chart
/// centered at 90°S. Supports tap selection, active marker highlighting,
/// and instant inspection.
class LunarPolarMapWidget extends StatefulWidget {
  final List<LunarSite> sites;
  final LunarSite? selectedSite;
  final ValueChanged<LunarSite>? onSiteSelected;
  final void Function(LunarSite)? onOpenDetails;
  final void Function(LunarSite)? onOpenVisibility;
  final void Function(LunarSite)? onOpenPlanner;

  const LunarPolarMapWidget({
    super.key,
    required this.sites,
    this.selectedSite,
    this.onSiteSelected,
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

  @override
  void initState() {
    super.initState();
    _internalSelectedSite =
        widget.selectedSite ??
        (widget.sites.isNotEmpty ? widget.sites.first : null);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant LunarPolarMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedSite != null &&
        widget.selectedSite != _internalSelectedSite) {
      setState(() {
        _internalSelectedSite = widget.selectedSite;
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

    LunarSite? closestSite;
    double minDistance = double.infinity;

    for (final site in widget.sites) {
      final point = _coordsHelper.getMapPoint(site);
      if (point == null) continue;

      // Polar to Cartesian conversion
      final r = point.normalizedRadius * mapRadius;
      final angle = point.polarAngleRadians;
      // 0° longitude points up (-Y direction)
      final markerX = center.dx + r * math.sin(angle);
      final markerY = center.dy - r * math.cos(angle);

      final distance = (Offset(markerX, markerY) - localPosition).distance;
      if (distance < minDistance) {
        minDistance = distance;
        closestSite = site;
      }
    }

    // Tap threshold: within 32 pixels
    if (closestSite != null && minDistance < 36.0) {
      setState(() {
        _internalSelectedSite = closestSite;
      });
      widget.onSiteSelected?.call(closestSite);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final selected = _internalSelectedSite;

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
                // Custom Painter for Map Grid, Craters, and Markers
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        return GestureDetector(
                          onTapDown: (details) => _handleTapOnMap(
                            details.localPosition,
                            Size(constraints.maxWidth, constraints.maxHeight),
                          ),
                          child: CustomPaint(
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            painter: _PolarStereographicPainter(
                              sites: widget.sites,
                              selectedSite: selected,
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
                      '80°S - 90°S Stereographic',
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

        // Selected Site Preview Card with Quick Actions
        if (selected != null) _buildSelectedSitePreviewCard(context, selected),
      ],
    );
  }

  Widget _buildSelectedSitePreviewCard(BuildContext context, LunarSite site) {
    final theme = Theme.of(context);
    final point = _coordsHelper.getMapPoint(site);
    final distanceKm = point != null
        ? LunarMapCoordinatesHelper.distanceToSouthPoleKm(point.latitude)
        : null;

    final (badgeLabel, badgeColor) = switch (site.classification) {
      SiteClassification.highPriorityLandingSiteRegion => (
        'ARTEMIS CANDIDATE',
        AppColors.statusInfo,
      ),
      SiteClassification.nasaCatalogRegion => (
        'NASA REGION',
        AppColors.darkSecondary,
      ),
      SiteClassification.userDefined => (
        'USER DEFINED',
        AppColors.statusSuccess,
      ),
    };

    return ScientificCard(
      borderColor: theme.colorScheme.primary.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppConstants.space8),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: badgeColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppConstants.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            site.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppConstants.space8),
                        StatusBadge(label: site.siteCode, color: badgeColor),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      point != null
                          ? '${point.latitude.abs().toStringAsFixed(2)}°S, ${point.longitude.toStringAsFixed(1)}°E • ${distanceKm?.toStringAsFixed(1)} km from Pole'
                          : 'Coordinates Pending',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(label: badgeLabel, color: badgeColor),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            site.description,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppConstants.space12),
          const Divider(height: 1),
          const SizedBox(height: AppConstants.space12),
          // Action Buttons
          Wrap(
            spacing: AppConstants.space8,
            runSpacing: AppConstants.space8,
            children: [
              FilledButton.icon(
                onPressed: () => widget.onOpenDetails?.call(site),
                icon: const Icon(Icons.analytics_outlined, size: 16),
                label: const Text('Site Profile'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onOpenVisibility?.call(site),
                icon: const Icon(Icons.wb_sunny_outlined, size: 16),
                label: const Text('Visibility & Lighting'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.onOpenPlanner?.call(site),
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

/// CustomPainter rendering the polar stereographic grid, major craters, and site markers.
class _PolarStereographicPainter extends CustomPainter {
  final List<LunarSite> sites;
  final LunarSite? selectedSite;
  final LunarMapCoordinatesHelper coordsHelper;
  final double pulseValue;
  final Color primaryColor;

  _PolarStereographicPainter({
    required this.sites,
    required this.selectedSite,
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

      // Label latitude ring
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
        // Glowing pulse halo
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

      // Marker core
      final corePaint = Paint()
        ..color = isSelected ? Colors.white : markerColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(markerPos, isSelected ? 4.5 : 3.0, corePaint);

      // Label for high priority or selected sites
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
  }

  void _drawProminentCraters(Canvas canvas, Offset center, double mapRadius) {
    // List of major craters: (lat, lon, diameterKm, name)
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

      // 10 degrees lat = ~303 km surface. Scale diameter in pixels:
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
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.sites.length != sites.length;
  }
}
