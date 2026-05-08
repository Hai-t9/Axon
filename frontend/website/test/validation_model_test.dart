import 'package:flutter_test/flutter_test.dart';
import 'package:website/features/validation/data/validation_models.dart';

void main() {
  group('Validation Models Test', () {
    test('ValidationListResponse.fromJson correctly parses list of IDs', () {
      final json = {
        'image_ids': [101, 102, 103]
      };

      final response = ValidationListResponse.fromJson(json);

      expect(response.imageIds, [101, 102, 103]);
    });

    test('ValidationImage.fromJson correctly parses image details', () {
      final json = {
        'id': 50,
        'filepath': 'uploads/img1.jpg',
        'label': 'Cat',
      };

      final image = ValidationImage.fromJson(json);

      expect(image.imageId, 50);
      expect(image.filepath, 'uploads/img1.jpg');
      expect(image.currentLabel, 'Cat');
    });

    test('ValidationImage.fromJson handles missing label', () {
      final json = {
        'id': 51,
        'filepath': 'uploads/img2.png',
      };

      final image = ValidationImage.fromJson(json);

      expect(image.imageId, 51);
      expect(image.filepath, 'uploads/img2.png');
      expect(image.currentLabel, isNull);
    });

    test('ValidationPendingImage.fromJson correctly parses pending validations', () {
      final json = {
        'id': 99,
        'filepath': 'uploads/pending.jpg',
        'label': 'Dog',
      };

      final pending = ValidationPendingImage.fromJson(json);

      expect(pending.id, 99);
      expect(pending.filepath, 'uploads/pending.jpg');
      expect(pending.label, 'Dog');
    });

    test('ValidationVoteResponse.fromJson correctly parses vote submission response', () {
      final json = {
        'validation_id': 1000,
        'label': 'ConfirmedDog',
      };

      final voteResponse = ValidationVoteResponse.fromJson(json);

      expect(voteResponse.validationId, 1000);
      expect(voteResponse.label, 'ConfirmedDog');
    });
  });
}
