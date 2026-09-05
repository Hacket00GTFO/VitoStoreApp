import 'package:flutter_test/flutter_test.dart';

import 'package:vito_store_app/features/auth/domain/user.dart';

void main() {
  group('User.fromJson', () {
    test('creates a valid User from a complete JSON map', () {
      final json = {
        'id': 'user-1',
        'email': 'norbe@vito.com',
        'role': 'ADMIN',
        'firstName': 'Norbe',
        'lastName': 'Cogni',
        'phone': '+525512345678',
        'emailVerified': true,
      };

      final user = User.fromJson(json);

      expect(user.id, 'user-1');
      expect(user.email, 'norbe@vito.com');
      expect(user.role, 'ADMIN');
      expect(user.firstName, 'Norbe');
      expect(user.lastName, 'Cogni');
      expect(user.phone, '+525512345678');
      expect(user.emailVerified, isTrue);
    });

    test('defaults role to USER when missing', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
      });

      expect(user.role, 'USER');
    });

    test('handles missing optional fields (phone, firstName, lastName)', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
      });

      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
      expect(user.phone, isNull);
      expect(user.emailVerified, isNull);
    });
  });

  group('User.fullName', () {
    test('returns concatenated firstName and lastName when both present', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
        'firstName': 'Norbe',
        'lastName': 'Cogni',
      });

      expect(user.fullName, 'Norbe Cogni');
    });

    test('returns only firstName when lastName is missing', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
        'firstName': 'Norbe',
      });

      expect(user.fullName, 'Norbe');
    });

    test('returns only lastName when firstName is missing', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
        'lastName': 'Cogni',
      });

      expect(user.fullName, 'Cogni');
    });

    test('returns empty string when both firstName and lastName are null', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
      });

      expect(user.fullName, '');
    });
  });

  group('User.role helpers', () {
    test('isAdmin returns true for ADMIN role', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
        'role': 'ADMIN',
      });

      expect(user.isAdmin, isTrue);
      expect(user.isModerator, isFalse);
    });

    test('isModerator returns true for MODERATOR role', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
        'role': 'MODERATOR',
      });

      expect(user.isModerator, isTrue);
      expect(user.isAdmin, isFalse);
    });

    test('isAdmin and isModerator are false for USER role', () {
      final user = User.fromJson({
        'id': 'u',
        'email': 'a@b.com',
        'role': 'USER',
      });

      expect(user.isAdmin, isFalse);
      expect(user.isModerator, isFalse);
    });
  });

  group('User.toJson', () {
    test('round-trips the user fields', () {
      final user = User(
        id: 'u',
        email: 'a@b.com',
        role: 'ADMIN',
        firstName: 'Norbe',
        lastName: 'Cogni',
        phone: '+52',
        emailVerified: true,
      );

      final json = user.toJson();

      expect(json['id'], 'u');
      expect(json['email'], 'a@b.com');
      expect(json['role'], 'ADMIN');
      expect(json['firstName'], 'Norbe');
      expect(json['lastName'], 'Cogni');
      expect(json['phone'], '+52');
      expect(json['emailVerified'], isTrue);
    });
  });
}
