import 'package:datingapp/discovery/domain/boost_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BoostStatus', () {
    test('canActivateAnother is true with quota remaining', () {
      const status = BoostStatus(
        active: false,
        endsAt: null,
        usedThisMonth: 1,
        limit: 2,
      );

      expect(status.canActivateAnother, isTrue);
    });

    test('canActivateAnother is false once the limit is used', () {
      const status = BoostStatus(
        active: false,
        endsAt: null,
        usedThisMonth: 2,
        limit: 2,
      );

      expect(status.canActivateAnother, isFalse);
    });

    test('canActivateAnother is false while one is already active', () {
      const status = BoostStatus(
        active: true,
        endsAt: null,
        usedThisMonth: 0,
        limit: 2,
      );

      expect(status.canActivateAnother, isFalse);
    });

    test('canActivateAnother is false for a non-subscriber', () {
      const status = BoostStatus(
        active: false,
        endsAt: null,
        usedThisMonth: 0,
        limit: null,
      );

      expect(status.isEntitled, isFalse);
      expect(status.canActivateAnother, isFalse);
    });
  });
}
