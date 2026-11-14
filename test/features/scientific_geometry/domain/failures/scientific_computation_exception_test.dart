import 'package:flutter_test/flutter_test.dart';
import 'package:luna_sight/features/scientific_geometry/scientific_geometry.dart';

void main() {
  group('ScientificComputationException', () {
    test('Constructs with message, code, and default empty context', () {
      final ex = ScientificComputationException(
        message: 'Something went wrong',
        code: 'GENERIC_ERROR',
      );

      expect(ex.message, 'Something went wrong');
      expect(ex.code, 'GENERIC_ERROR');
      expect(ex.context, isEmpty);
    });

    test('Allows supported primitive and scalar values in context map', () {
      final ex = ScientificComputationException(
        message: 'Test message',
        code: 'TEST_CODE',
        context: {
          'stringKey': 'stringVal',
          'intKey': 42,
          'doubleKey': 3.14159,
          'boolKey': true,
          'nullKey': null,
        },
      );

      expect(ex.context['stringKey'], 'stringVal');
      expect(ex.context['intKey'], 42);
      expect(ex.context['doubleKey'], 3.14159);
      expect(ex.context['boolKey'], true);
      expect(ex.context['nullKey'], isNull);
    });

    test('Enforces defensive copy and unmodifiable context map', () {
      final rawContext = <String, Object?>{'key': 'initial'};
      final ex = ScientificComputationException(
        message: 'Test',
        code: 'TEST',
        context: rawContext,
      );

      // Mutating original map does not mutate context
      rawContext['key'] = 'modified';
      expect(ex.context['key'], 'initial');

      // Mutating context map throws UnsupportedError
      expect(() => ex.context['newKey'] = 'value', throwsUnsupportedError);
      expect(() => ex.context.remove('key'), throwsUnsupportedError);
    });

    test('Strictly rejects non-scalar or mutable objects in context', () {
      expect(
        () => ScientificComputationException(
          message: 'Test',
          code: 'TEST',
          context: {
            'list': [1, 2, 3],
          },
        ),
        throwsArgumentError,
      );

      expect(
        () => ScientificComputationException(
          message: 'Test',
          code: 'TEST',
          context: {
            'map': {'nested': 'val'},
          },
        ),
        throwsArgumentError,
      );

      expect(
        () => ScientificComputationException(
          message: 'Test',
          code: 'TEST',
          context: {
            'set': {1, 2},
          },
        ),
        throwsArgumentError,
      );

      expect(
        () => ScientificComputationException(
          message: 'Test',
          code: 'TEST',
          context: {'object': Object()},
        ),
        throwsArgumentError,
      );
    });

    test(
      'Equality and hashCode respect message, code, and context content',
      () {
        final ex1 = ScientificComputationException(
          message: 'msg',
          code: 'CODE',
          context: {'k': 1},
        );
        final ex2 = ScientificComputationException(
          message: 'msg',
          code: 'CODE',
          context: {'k': 1},
        );
        final ex3 = ScientificComputationException(
          message: 'other',
          code: 'CODE',
          context: {'k': 1},
        );
        final ex4 = ScientificComputationException(
          message: 'msg',
          code: 'OTHER',
          context: {'k': 1},
        );
        final ex5 = ScientificComputationException(
          message: 'msg',
          code: 'CODE',
          context: {'k': 2},
        );

        expect(ex1, equals(ex2));
        expect(ex1.hashCode, equals(ex2.hashCode));
        expect(ex1, isNot(equals(ex3)));
        expect(ex1, isNot(equals(ex4)));
        expect(ex1, isNot(equals(ex5)));
      },
    );

    test('toString formats code, message, and context', () {
      final ex = ScientificComputationException(
        message: 'Err',
        code: 'CODE',
        context: {'a': 1},
      );
      expect(
        ex.toString(),
        'ScientificComputationException(CODE: Err, context: {a: 1})',
      );
    });
  });
}
