import 'package:flutter_test/flutter_test.dart';
import 'package:maestro/features/projects/domain/project_models.dart';

void main() {
  group('ProjectName', () {
    test(
      'GivenPaddedMixedCaseName_WhenParsed_ThenDisplayAndKeyAreCanonical',
      () {
        final name = ProjectName.parse('  My Project  ');

        expect(name.displayValue, 'My Project');
        expect(name.normalizedKey, 'my project');
      },
    );

    test('GivenInvalidNameBoundaries_WhenParsed_ThenTypedReasonIsThrown', () {
      final cases = <(String, InvalidProjectNameReason)>[
        ('', InvalidProjectNameReason.empty),
        ('   ', InvalidProjectNameReason.empty),
        ('bad\nname', InvalidProjectNameReason.controlCharacter),
        ('bad\u0000name', InvalidProjectNameReason.controlCharacter),
        (
          'x' * (ProjectName.maximumLength + 1),
          InvalidProjectNameReason.tooLong,
        ),
      ];

      for (final (input, reason) in cases) {
        expect(
          () => ProjectName.parse(input),
          throwsA(
            isA<InvalidProjectName>().having(
              (failure) => failure.reason,
              'reason',
              reason,
            ),
          ),
          reason: reason.name,
        );
      }
    });

    test('GivenMaximumLengthName_WhenParsed_ThenItIsAccepted', () {
      final value = 'x' * ProjectName.maximumLength;

      expect(ProjectName.parse(value).displayValue, value);
    });
  });

  group('ProjectFolder', () {
    test('GivenAbsolutePlatformPaths_WhenParsed_ThenReferencesAreRetained', () {
      expect(ProjectFolder.parse('/work/project').path, '/work/project');
      expect(ProjectFolder.parse(r'C:\work\project').path, r'C:\work\project');
      expect(
        ProjectFolder.parse(r'\\server\share\project').path,
        r'\\server\share\project',
      );
    });

    test('GivenRelativeOrUnsafePath_WhenParsed_ThenTypedReasonIsThrown', () {
      final cases = <String>[
        '',
        'project',
        r'.\project',
        '../project',
        '/bad\npath',
      ];

      for (final input in cases) {
        expect(
          () => ProjectFolder.parse(input),
          throwsA(isA<InvalidProjectFolder>()),
        );
      }
    });
  });
}
