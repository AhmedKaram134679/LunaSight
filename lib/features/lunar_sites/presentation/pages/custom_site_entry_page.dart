import 'package:flutter/material.dart';
import 'package:luna_sight/core/constants/app_constants.dart';
import 'package:luna_sight/core/utils/responsive_layout.dart';
import 'package:luna_sight/features/lunar_sites/domain/entities/lunar_coordinates.dart';
import 'package:luna_sight/features/lunar_sites/domain/repositories/lunar_site_repository.dart';

/// Form page enabling the user to enter custom selenographic coordinates.
class CustomSiteEntryPage extends StatefulWidget {
  final LunarSiteRepository repository;

  const CustomSiteEntryPage({super.key, required this.repository});

  @override
  State<CustomSiteEntryPage> createState() => _CustomSiteEntryPageState();
}

class _CustomSiteEntryPageState extends State<CustomSiteEntryPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _altitudeController = TextEditingController();
  final _descriptionController = TextEditingController();

  LongitudeConvention _convention = LongitudeConvention.eastPositive;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _altitudeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final lat = double.parse(_latitudeController.text.trim());
      final lon = double.parse(_longitudeController.text.trim());
      final altText = _altitudeController.text.trim();
      final alt = altText.isNotEmpty ? double.tryParse(altText) : null;

      final coords = LunarCoordinates(
        latitude: lat,
        longitude: lon,
        longitudeConvention: _convention,
        provenance: CoordinateProvenance.userEntered,
        altitudeMeters: alt,
      );

      final newSite = await widget.repository.addCustomSite(
        name: _nameController.text.trim(),
        coordinates: coords,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(newSite);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage = 'Failed to save site: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = ResponsiveLayout.isCompact(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Custom Site Entry')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact
                    ? AppConstants.space16
                    : AppConstants.space24,
                vertical: AppConstants.space16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Define Custom Coordinate Location',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppConstants.space8),
                    Text(
                      'Specify selenographic coordinates for high-priority evaluation, scientific analysis, or traverse planning. Values are verified within lunar angular limits.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppConstants.space24),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppConstants.space12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMedium,
                          ),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.space16),
                    ],
                    TextFormField(
                      key: const Key('custom_site_name_field'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Site Name *',
                        hintText: 'e.g., Artemis III Candidate Alpha',
                        prefixIcon: Icon(Icons.bookmark_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Site name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.space16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const Key('custom_site_latitude_field'),
                            controller: _latitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Latitude (°)*',
                              hintText: '-89.9000',
                              helperText: 'Range: -90.0° to +90.0°',
                              prefixIcon: Icon(Icons.north),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final val = double.tryParse(value.trim());
                              if (val == null) return 'Invalid number';
                              return LunarCoordinates.validateLatitude(val);
                            },
                          ),
                        ),
                        const SizedBox(width: AppConstants.space16),
                        Expanded(
                          child: TextFormField(
                            key: const Key('custom_site_longitude_field'),
                            controller: _longitudeController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Longitude (°)*',
                              hintText: '0.0000',
                              helperText: 'Range: -180° to +360°',
                              prefixIcon: Icon(Icons.east),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              final val = double.tryParse(value.trim());
                              if (val == null) return 'Invalid number';
                              return LunarCoordinates.validateLongitude(val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.space16),
                    DropdownButtonFormField<LongitudeConvention>(
                      key: const Key('custom_site_convention_dropdown'),
                      initialValue: _convention,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Longitude Directional Convention',
                        prefixIcon: Icon(Icons.explore_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: LongitudeConvention.eastPositive,
                          child: Text(
                            'East-Positive (0° to 360° / IAU standard)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        DropdownMenuItem(
                          value: LongitudeConvention.westPositive,
                          child: Text(
                            'West-Positive',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _convention = val);
                        }
                      },
                    ),
                    const SizedBox(height: AppConstants.space16),
                    TextFormField(
                      key: const Key('custom_site_altitude_field'),
                      controller: _altitudeController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Surface Elevation / Altitude (meters)',
                        hintText: 'Optional elevation relative to lunar radius',
                        prefixIcon: Icon(Icons.height),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return null;
                        if (double.tryParse(value.trim()) == null) {
                          return 'Must be a valid decimal number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppConstants.space16),
                    TextFormField(
                      key: const Key('custom_site_description_field'),
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Exploration Context',
                        hintText: 'Rationale, mission context, or notes...',
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: AppConstants.space24),
                    FilledButton.icon(
                      key: const Key('custom_site_submit_button'),
                      onPressed: _isSaving ? null : _submitForm,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _isSaving ? 'Saving Site...' : 'Add Lunar Site',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
