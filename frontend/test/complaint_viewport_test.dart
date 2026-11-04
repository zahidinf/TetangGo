import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tetanggo_frontend/features/auth/domain/models/user_model.dart';
import 'package:tetanggo_frontend/features/complaint/data/repositories/complaint_repository.dart';
import 'package:tetanggo_frontend/features/complaint/domain/models/complaint_model.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/admin_complaint_bloc.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/complaint_bloc.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/screens/admin_complaints_screen.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/screens/resident_complaints_screen.dart';
import 'resident_complaints_test.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  final testUser = UserModel(
    id: 1,
    roleId: 1,
    salutation: 'Bpk.',
    name: 'Admin TetangGo',
    phone: '081234567890',
    email: 'admin@tetanggo.id',
    role: 'ADMIN',
    status: 'active',
    ownershipStatus: 'owner',
    houseId: 101,
  );

  testWidgets('ResidentComplaintsScreen renders at 320x568 without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeComplaintRepository();
    repo.items.add(
      ComplaintModel(
        id: 1,
        ticketNumber: 'TKT-20261027-001',
        userId: 1,
        houseId: 10,
        title: 'Lampu jalan utama dekat pos satpam padam total',
        description: 'Lampu sudah 2 hari tidak menyala sehingga jalanan gelap',
        category: ComplaintCategory.lampuJalan,
        photoUrl: '/api/v1/complaints/photo/test.jpg',
        status: ComplaintStatus.menunggu,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reporterName: 'Warga Boni',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<ComplaintRepository>.value(
          value: repo,
          child: BlocProvider<ComplaintBloc>(
            create: (ctx) => ComplaintBloc(repository: repo),
            child: const ResidentComplaintsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminComplaintsScreen renders at 320x568 without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final repo = FakeComplaintRepository();
    repo.items.add(
      ComplaintModel(
        id: 1,
        ticketNumber: 'TKT-20261027-001',
        userId: 1,
        houseId: 10,
        title: 'Lampu jalan utama dekat pos satpam padam total',
        description: 'Lampu sudah 2 hari tidak menyala sehingga jalanan gelap',
        category: ComplaintCategory.lampuJalan,
        photoUrl: '/api/v1/complaints/photo/test.jpg',
        status: ComplaintStatus.menunggu,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reporterName: 'Warga Boni',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RepositoryProvider<ComplaintRepository>.value(
          value: repo,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AdminComplaintBloc>(
                create: (ctx) => AdminComplaintBloc(repository: repo),
              ),
              BlocProvider<ComplaintBloc>(
                create: (ctx) => ComplaintBloc(repository: repo),
              ),
            ],
            child: AdminComplaintsScreen(currentUser: testUser),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
