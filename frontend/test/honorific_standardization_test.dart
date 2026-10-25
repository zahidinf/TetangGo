import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dio/dio.dart';
import 'package:tetanggo_frontend/core/utils/honorific_helper.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/resident_management/data/resident_repository.dart';
import 'package:tetanggo_frontend/features/resident_management/domain/models/resident_user_model.dart';
import 'package:tetanggo_frontend/features/resident_management/domain/models/occupant_model.dart';
import 'package:tetanggo_frontend/features/resident_management/domain/models/pending_user_model.dart';
import 'package:tetanggo_frontend/features/resident_management/presentation/widgets/user_form_dialog.dart';

class FakeResidentRepository extends ResidentRepository {
  FakeResidentRepository() : super(dio: Dio());

  Map<String, dynamic>? lastUpdatedPayload;

  @override
  Future<ResidentUserModel> adminUpdateUser({
    required int userId,
    String salutation = HonorificHelper.bapak,
    required String name,
    required String phone,
    required String email,
    int? houseId,
    String role = 'RESIDENT',
    String status = 'active',
    String ownershipStatus = 'pemilik',
  }) async {
    lastUpdatedPayload = {
      'userId': userId,
      'salutation': salutation,
      'name': name,
      'phone': phone,
      'email': email,
      'houseId': houseId,
      'role': role,
      'status': status,
      'ownershipStatus': ownershipStatus,
    };

    return ResidentUserModel(
      id: userId,
      salutation: salutation,
      name: name,
      phone: phone,
      email: email,
      role: role,
      status: status,
      ownershipStatus: ownershipStatus,
      houseId: houseId,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  group('Honorific Normalization Rule Tests', () {
    test(
        'Rule A: Map Mba, Mbak, Mama, Mamah (and case/space variations) to Ibu',
        () {
      expect(HonorificHelper.normalize('Ibu'), equals('Ibu'));
      expect(HonorificHelper.normalize('ibu'), equals('Ibu'));
      expect(HonorificHelper.normalize('IBU'), equals('Ibu'));
      expect(HonorificHelper.normalize('  Ibu  '), equals('Ibu'));
      expect(HonorificHelper.normalize('Mba'), equals('Ibu'));
      expect(HonorificHelper.normalize('mba'), equals('Ibu'));
      expect(HonorificHelper.normalize('MBA'), equals('Ibu'));
      expect(HonorificHelper.normalize('  Mba  '), equals('Ibu'));
      expect(HonorificHelper.normalize('Mbak'), equals('Ibu'));
      expect(HonorificHelper.normalize('mbak'), equals('Ibu'));
      expect(HonorificHelper.normalize('MBAK'), equals('Ibu'));
      expect(HonorificHelper.normalize('Mama'), equals('Ibu'));
      expect(HonorificHelper.normalize('mama'), equals('Ibu'));
      expect(HonorificHelper.normalize('MAMA'), equals('Ibu'));
      expect(HonorificHelper.normalize('Mamah'), equals('Ibu'));
      expect(HonorificHelper.normalize('mamah'), equals('Ibu'));
      expect(HonorificHelper.normalize('MAMAH'), equals('Ibu'));
    });

    test('Rule B: Map every other honorific value to Bapak', () {
      expect(HonorificHelper.normalize(' Pak '), equals('Bapak'));
      expect(HonorificHelper.normalize('Pak'), equals('Bapak'));
      expect(HonorificHelper.normalize('pak'), equals('Bapak'));
      expect(HonorificHelper.normalize('PAK'), equals('Bapak'));
      expect(HonorificHelper.normalize('Bapak'), equals('Bapak'));
      expect(HonorificHelper.normalize('bapak'), equals('Bapak'));
      expect(HonorificHelper.normalize('BAPAK'), equals('Bapak'));
      expect(HonorificHelper.normalize('Bp'), equals('Bapak'));
      expect(HonorificHelper.normalize('bp'), equals('Bapak'));
      expect(HonorificHelper.normalize('BP'), equals('Bapak'));
      expect(HonorificHelper.normalize('Mas'), equals('Bapak'));
      expect(HonorificHelper.normalize('mas'), equals('Bapak'));
      expect(HonorificHelper.normalize('MAS'), equals('Bapak'));
      expect(HonorificHelper.normalize('Kak'), equals('Bapak'));
      expect(HonorificHelper.normalize('kak'), equals('Bapak'));
      expect(HonorificHelper.normalize('KAK'), equals('Bapak'));
      expect(HonorificHelper.normalize('Tuan'), equals('Bapak'));
      expect(HonorificHelper.normalize(''), equals('Bapak'));
      expect(HonorificHelper.normalize('   '), equals('Bapak'));
      expect(HonorificHelper.normalize(null), equals('Bapak'));
      expect(HonorificHelper.normalize('Unknown value'), equals('Bapak'));
      expect(HonorificHelper.normalize('random_string'), equals('Bapak'));
    });

    test('Canonical options list contains exactly two choices: Bapak and Ibu',
        () {
      expect(HonorificHelper.canonicalOptions, equals(['Bapak', 'Ibu']));
      expect(HonorificHelper.canonicalOptions.length, equals(2));
      expect(HonorificHelper.canonicalOptions.contains('Pak'), isFalse);
      expect(HonorificHelper.canonicalOptions.contains('Mba'), isFalse);
      expect(HonorificHelper.canonicalOptions.contains('Mbak'), isFalse);
      expect(HonorificHelper.canonicalOptions.contains('Mama'), isFalse);
    });

    test('formatDisplayName standardizes prefix and handles empty names', () {
      expect(HonorificHelper.formatDisplayName('Pak', 'Farhan'),
          equals('Bapak Farhan'));
      expect(
          HonorificHelper.formatDisplayName('Mba', 'Ica'), equals('Ibu Ica'));
      expect(HonorificHelper.formatDisplayName('Mama', 'Rizki'),
          equals('Ibu Rizki'));
      expect(HonorificHelper.formatDisplayName('Mamah', 'Siti'),
          equals('Ibu Siti'));
      expect(HonorificHelper.formatDisplayName('Bp', 'Budi'),
          equals('Bapak Budi'));
      expect(HonorificHelper.formatDisplayName('', 'Farhan'),
          equals('Bapak Farhan'));
      expect(HonorificHelper.formatDisplayName(null, 'Farhan'),
          equals('Bapak Farhan'));
      expect(HonorificHelper.formatDisplayName('Bapak', ''), equals('Bapak'));
    });
  });

  group('Model Normalization and Display Name Tests', () {
    test(
        'UserModel normalizes legacy values and formats displayName as Bapak/Ibu',
        () {
      final userPak = UserModel.fromJson({
        'id': 1,
        'salutation': 'Pak',
        'name': 'Farhan',
        'phone': '081234567890',
        'email': 'farhan@tetanggo.id',
        'role_id': 244,
        'role': 'ADMIN',
        'status': 'active',
      });
      expect(userPak.salutation, equals('Bapak'));
      expect(userPak.displayName, equals('Bapak Farhan'));

      final userMba = UserModel.fromJson({
        'id': 2,
        'salutation': 'Mba',
        'name': 'Ica',
        'phone': '081234567891',
        'email': 'ica@tetanggo.id',
        'role_id': 249,
        'role': 'RESIDENT',
        'status': 'active',
      });
      expect(userMba.salutation, equals('Ibu'));
      expect(userMba.displayName, equals('Ibu Ica'));

      final userMama = UserModel.fromJson({
        'id': 3,
        'salutation': 'Mama',
        'name': 'Rizki',
        'phone': '081234567892',
        'email': 'rizki@tetanggo.id',
        'role_id': 249,
        'role': 'RESIDENT',
        'status': 'active',
      });
      expect(userMama.salutation, equals('Ibu'));
      expect(userMama.displayName, equals('Ibu Rizki'));

      final userEmpty = UserModel.fromJson({
        'id': 4,
        'salutation': '',
        'name': 'Yani',
        'phone': '081234567893',
        'email': 'yani@tetanggo.id',
        'role_id': 249,
        'role': 'RESIDENT',
        'status': 'active',
      });
      expect(userEmpty.salutation, equals('Bapak'));
      expect(userEmpty.displayName, equals('Bapak Yani'));
    });

    test(
        'ResidentUserModel normalizes salutation and generates correct displayName',
        () {
      final residentMbak = ResidentUserModel.fromJson({
        'id': 10,
        'salutation': 'Mbak',
        'name': 'Dela',
        'phone': '081234567894',
        'email': 'dela@tetanggo.id',
        'role': 'RESIDENT',
        'status': 'active',
        'ownership_status': 'pemilik',
      });
      expect(residentMbak.salutation, equals('Ibu'));
      expect(residentMbak.displayName, equals('Ibu Dela'));

      final residentBp = ResidentUserModel.fromJson({
        'id': 11,
        'salutation': 'Bp',
        'name': 'Budi',
        'phone': '081234567895',
        'email': 'budi@tetanggo.id',
        'role': 'RESIDENT',
        'status': 'active',
        'ownership_status': 'pemilik',
      });
      expect(residentBp.salutation, equals('Bapak'));
      expect(residentBp.displayName, equals('Bapak Budi'));
    });

    test(
        'HouseOccupantModel and PendingUserModel normalize honorifics properly',
        () {
      final occupant = HouseOccupantModel.fromJson({
        'id': 20,
        'salutation': 'Mamah',
        'name': 'Dewi',
        'phone': '081234567896',
        'email': 'dewi@tetanggo.id',
        'role': 'RESIDENT',
        'ownership_status': 'pemilik',
      });
      expect(occupant.salutation, equals('Ibu'));
      expect(occupant.displayName, equals('Ibu Dewi'));

      final pending = PendingUserModel.fromJson({
        'id': 30,
        'salutation': 'Kak',
        'name': 'Doni',
        'phone': '081234567897',
        'email': 'doni@tetanggo.id',
        'role': 'RESIDENT',
        'ownership_status': 'pemilik',
        'house_block': 'B1',
        'house_number': '10',
      });
      expect(pending.salutation, equals('Bapak'));
      expect(pending.displayName, equals('Bapak Doni'));
    });
  });

  group('UserFormDialog Account Editing and Dropdown Tests', () {
    late FakeResidentRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeResidentRepository();
    });

    Widget createTestWidget(ResidentUserModel? userToEdit) {
      return MaterialApp(
        home: RepositoryProvider<ResidentRepository>.value(
          value: fakeRepo,
          child: Scaffold(
            body: UserFormDialog(
              userToEdit: userToEdit,
              houses: const [],
              onSaved: () {},
            ),
          ),
        ),
      );
    }

    testWidgets(
        'Opening resident with legacy "Pak" selects "Bapak" without crash',
        (tester) async {
      final user = ResidentUserModel.fromJson({
        'id': 100,
        'salutation': 'Pak',
        'name': 'Irvan',
        'phone': '081210000012',
        'email': 'irvan@tetanggo.id',
        'role': 'CHAIRPERSON',
        'status': 'active',
        'ownership_status': 'pemilik',
      });

      await tester.pumpWidget(createTestWidget(user));
      await tester.pumpAndSettle();

      // Dropdown must display Bapak
      expect(find.text('Bapak'), findsWidgets);
      // "Pak" must NOT be rendered as a dropdown item value
      expect(
          find.widgetWithText(DropdownMenuItem<String>, 'Pak'), findsNothing);
    });

    testWidgets(
        'Opening resident with legacy "Mba", "Mbak", "Mama", "Mamah" selects "Ibu"',
        (tester) async {
      for (final legacy in ['Mba', 'Mbak', 'Mama', 'Mamah']) {
        final user = ResidentUserModel.fromJson({
          'id': 101,
          'salutation': legacy,
          'name': 'Test Warga',
          'phone': '081210000099',
          'email': 'test@tetanggo.id',
          'role': 'RESIDENT',
          'status': 'active',
          'ownership_status': 'pemilik',
        });

        await tester.pumpWidget(createTestWidget(user));
        await tester.pumpAndSettle();

        expect(find.text('Ibu'), findsWidgets);
        expect(find.widgetWithText(DropdownMenuItem<String>, legacy),
            findsNothing);
      }
    });

    testWidgets('Dropdown contains exactly two options: Bapak and Ibu',
        (tester) async {
      await tester.pumpWidget(createTestWidget(null));
      await tester.pumpAndSettle();

      // Tap the salutation dropdown to open its menu
      final dropdownFinder = find.byKey(const ValueKey('salutation_dropdown'));
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Should have DropdownMenuItems for Bapak and Ibu
      final bapakItems = find.widgetWithText(DropdownMenuItem<String>, 'Bapak');
      final ibuItems = find.widgetWithText(DropdownMenuItem<String>, 'Ibu');
      expect(bapakItems, findsWidgets);
      expect(ibuItems, findsWidgets);

      // Verify no other honorifics exist in dropdown
      expect(
          find.widgetWithText(DropdownMenuItem<String>, 'Pak'), findsNothing);
      expect(
          find.widgetWithText(DropdownMenuItem<String>, 'Mba'), findsNothing);
      expect(
          find.widgetWithText(DropdownMenuItem<String>, 'Mbak'), findsNothing);
      expect(
          find.widgetWithText(DropdownMenuItem<String>, 'Mama'), findsNothing);
      expect(
          find.widgetWithText(DropdownMenuItem<String>, 'Mamah'), findsNothing);
    });

    testWidgets(
        'Updating resident from Bapak to Ibu and saving preserves unrelated fields',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final user = ResidentUserModel.fromJson({
        'id': 105,
        'salutation': 'Pak',
        'name': 'Farhan',
        'phone': '081381471120',
        'email': 'farhan@tetanggo.id',
        'role': 'ADMIN',
        'status': 'active',
        'ownership_status': 'pemilik',
      });

      await tester.pumpWidget(createTestWidget(user));
      await tester.pumpAndSettle();

      // Open dropdown and select Ibu
      final dropdownFinder = find.byKey(const ValueKey('salutation_dropdown'));
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Tap 'Ibu' text inside the opened popup menu
      final ibuItemFinder =
          find.widgetWithText(DropdownMenuItem<String>, 'Ibu').last;
      await tester.tap(ibuItemFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Submit form
      final saveButton =
          find.widgetWithText(ElevatedButton, 'Simpan Perubahan');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.pumpAndSettle();
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify repository was called with salutation 'Ibu' and untouched fields
      expect(fakeRepo.lastUpdatedPayload, isNotNull);
      expect(fakeRepo.lastUpdatedPayload!['userId'], equals(105));
      expect(fakeRepo.lastUpdatedPayload!['salutation'], equals('Ibu'));
      expect(fakeRepo.lastUpdatedPayload!['name'], equals('Farhan'));
      expect(fakeRepo.lastUpdatedPayload!['phone'], equals('081381471120'));
      expect(
          fakeRepo.lastUpdatedPayload!['email'], equals('farhan@tetanggo.id'));
      expect(fakeRepo.lastUpdatedPayload!['role'], equals('ADMIN'));
      expect(fakeRepo.lastUpdatedPayload!['status'], equals('active'));
      expect(
          fakeRepo.lastUpdatedPayload!['ownershipStatus'], equals('pemilik'));
    });
  });
}
