import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';

void main() {
  group('ReferenceFrameId and CoordinateOriginId and VectorUnit', () {
    test('ReferenceFrameId constants and verified NAIF IDs', () {
      expect(ReferenceFrameId.icrf.name, 'ICRF');
      expect(ReferenceFrameId.icrf.naifId, isNull);

      expect(ReferenceFrameId.j2000.name, 'J2000');
      expect(ReferenceFrameId.j2000.naifId, 1);

      // DE421
      expect(ReferenceFrameId.moonMeDe421.name, 'MOON_ME_DE421');
      expect(ReferenceFrameId.moonMeDe421.naifId, 31007);
      expect(ReferenceFrameId.moonMeDe421.ephemerisVersion, 'DE421');

      expect(ReferenceFrameId.moonPaDe421.name, 'MOON_PA_DE421');
      expect(ReferenceFrameId.moonPaDe421.naifId, 31006);
      expect(ReferenceFrameId.moonPaDe421.ephemerisVersion, 'DE421');

      // DE440
      expect(ReferenceFrameId.moonMeDe440.name, 'MOON_ME_DE440_ME421');
      expect(ReferenceFrameId.moonMeDe440.naifId, 31009);
      expect(ReferenceFrameId.moonMeDe440.ephemerisVersion, 'DE440');

      expect(ReferenceFrameId.moonPaDe440.name, 'MOON_PA_DE440');
      expect(ReferenceFrameId.moonPaDe440.naifId, 31008);
      expect(ReferenceFrameId.moonPaDe440.ephemerisVersion, 'DE440');

      expect(ReferenceFrameId.moonPa.name, 'MOON_PA');
      expect(ReferenceFrameId.moonPa.naifId, 31010);
      expect(ReferenceFrameId.moonPa.ephemerisVersion, 'DE440');

      expect(ReferenceFrameId.moonMe.name, 'MOON_ME');
      expect(ReferenceFrameId.moonMe.naifId, 31011);
      expect(ReferenceFrameId.moonMe.ephemerisVersion, 'DE440');
    });

    test('ReferenceFrameId equality prevents accidental equivalence between DE421 and DE440', () {
      expect(
        ReferenceFrameId.moonMeDe421,
        isNot(equals(ReferenceFrameId.moonMeDe440)),
      );
      expect(
        ReferenceFrameId.moonPaDe421,
        isNot(equals(ReferenceFrameId.moonPaDe440)),
      );
      expect(ReferenceFrameId.icrf, isNot(equals(ReferenceFrameId.j2000)));

      // Identical definition matches
      const customMeDe421 = ReferenceFrameId(
        name: 'MOON_ME_DE421',
        naifId: 31007,
        ephemerisVersion: 'DE421',
      );
      expect(ReferenceFrameId.moonMeDe421, equals(customMeDe421));
      expect(
        ReferenceFrameId.moonMeDe421.hashCode,
        equals(customMeDe421.hashCode),
      );
    });

    test('CoordinateOriginId constants and factory', () {
      expect(CoordinateOriginId.ssb.name, 'SOLAR_SYSTEM_BARYCENTER');
      expect(CoordinateOriginId.ssb.naifBodyId, 0);

      expect(CoordinateOriginId.moonCenterOfMass.name, 'MOON_CENTER_OF_MASS');
      expect(CoordinateOriginId.moonCenterOfMass.naifBodyId, 301);

      expect(CoordinateOriginId.earthCenterOfMass.name, 'EARTH_CENTER_OF_MASS');
      expect(CoordinateOriginId.earthCenterOfMass.naifBodyId, 399);

      final site = CoordinateOriginId.topocentricSite('shackleton_rim');
      expect(site.name, 'TOPOCENTRIC_LUNAR_SITE');
      expect(site.siteIdentifier, 'shackleton_rim');
      expect(site.naifBodyId, isNull);
    });

    test('CoordinateOriginId equality separates lunar center of mass and topocentric site', () {
      final site = CoordinateOriginId.topocentricSite('shackleton');
      expect(CoordinateOriginId.moonCenterOfMass, isNot(equals(site)));
      expect(
        CoordinateOriginId.earthCenterOfMass,
        isNot(equals(CoordinateOriginId.moonCenterOfMass)),
      );

      final site2 = CoordinateOriginId.topocentricSite('shackleton');
      expect(site, equals(site2));
      expect(site.hashCode, equals(site2.hashCode));
    });

    test(
      'VectorUnit enumeration contains meters, kilometers, dimensionless',
      () {
        expect(
          VectorUnit.values,
          containsAll([
            VectorUnit.meters,
            VectorUnit.kilometers,
            VectorUnit.dimensionless,
          ]),
        );
      },
    );
  });
}
