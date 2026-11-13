import 'package:flutter/material.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/widgets/scientific_card.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';

/// Presentation widget displaying selenographic coordinates with convention and provenance indicators.
class CoordinateDisplayWidget extends StatelessWidget {
  final LunarCoordinates? coordinates;

  const CoordinateDisplayWidget({super.key, required this.coordinates});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (coordinates == null) {
      return ScientificCard(
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: theme.colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: AppConstants.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Point Coordinates Unavailable',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'This region is published by NASA GSFC PGDA as a spatial raster footprint (bounding box), without a designated single-point landing coordinate.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final coords = coordinates!;
    final conventionText = switch (coords.longitudeConvention) {
      LongitudeConvention.eastPositive => 'East-Positive (IAU Standard)',
      LongitudeConvention.westPositive => 'West-Positive',
      LongitudeConvention.unknown => 'Unspecified Convention',
    };

    final provenanceText = switch (coords.provenance) {
      CoordinateProvenance.nasaPublished => 'NASA Published',
      CoordinateProvenance.userEntered => 'Operator Defined',
    };

    return ScientificCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Selenographic Coordinates',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Text(
                  provenanceText,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.space12),
          Text(
            coords.formattedCoordinates,
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppConstants.space8),
          Divider(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: AppConstants.space8),
          _buildDetailRow(
            context,
            'Latitude:',
            '${coords.latitude.toStringAsFixed(6)}°',
          ),
          const SizedBox(height: 4),
          _buildDetailRow(
            context,
            'Longitude:',
            '${coords.longitude.toStringAsFixed(6)}°',
          ),
          const SizedBox(height: 4),
          _buildDetailRow(context, 'Convention:', conventionText),
          if (coords.altitudeMeters != null) ...[
            const SizedBox(height: 4),
            _buildDetailRow(
              context,
              'Elevation / Altitude:',
              '${coords.altitudeMeters!.toStringAsFixed(1)} m',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
