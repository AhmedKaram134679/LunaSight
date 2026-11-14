// Intentionally invalid Dart source fixture.
//
// This file attempts to implement `LunarCoordinateTransformer` outside of its defining
// library (`lunar_coordinate_transformer.dart`). Because `LunarCoordinateTransformer`
// is declared as a `final class`, Dart's compiler/analyzer must reject this code with
// the diagnostic `invalid_use_of_type_outside_library`.
//
// This fixture is excluded from standard analysis in `analysis_options.yaml` and is
// tested exclusively via the compile-time regression suite:
// `test/compile_time/lunar_coordinate_transformer_finality_test.dart`.

import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_coordinate_transformation_result.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_coordinate_transformer.dart';
import 'package:luna_sight/features/scientific_geometry/domain/coordinates/lunar_geographic_coordinates.dart';
import 'package:luna_sight/features/scientific_geometry/domain/value_objects/framed_vector3.dart';

// Prohibited external implementation:
class IllegalTransformerImplements implements LunarCoordinateTransformer {
  const IllegalTransformerImplements();

  @override
  FramedVector3 toBodyFixedCartesian(LunarGeographicCoordinates coords) {
    throw UnimplementedError();
  }

  @override
  LunarCoordinateTransformationResult transformWithProvenance(
    LunarGeographicCoordinates coords,
  ) {
    throw UnimplementedError();
  }
}
