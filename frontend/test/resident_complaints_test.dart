import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tetanggo_frontend/core/network/dio_client.dart';
import 'package:tetanggo_frontend/core/storage/secure_storage_service.dart';
import 'package:tetanggo_frontend/features/complaint/data/repositories/complaint_repository.dart';
import 'package:tetanggo_frontend/features/complaint/domain/models/complaint_model.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/complaint_bloc.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/complaint_event.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/bloc/complaint_state.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/screens/resident_complaints_screen.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/widgets/complaint_detail_dialog.dart';
import 'package:tetanggo_frontend/features/complaint/presentation/widgets/create_complaint_dialog.dart';

// Fake Complaint Repository for Unit & Widget Tests
class FakeComplaintRepository implements ComplaintRepository {
  final List<ComplaintModel> items = [];
  bool shouldFail = false;

  @override
  Future<ComplaintModel> createComplaint({
    required String title,
    required String description,
    required ComplaintCategory category,
    Uint8List? photoBytes,
    String? photoFileName,
  }) async {
    if (shouldFail) {
      throw Exception('Simulated network error');
    }
    final model = ComplaintModel(
      id: items.length + 1,
      ticketNumber: 'TKT-20261027-FAKE${items.length + 1}',
      userId: 1,
      houseId: 10,
      title: title,
      description: description,
      category: category,
      photoUrl: photoBytes != null ? '/api/v1/complaints/photo/test.jpg' : null,
      status: ComplaintStatus.menunggu,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      reporterName: 'Warga Boni',
      houseBlock: 'B1',
      houseNumber: '01',
    );
    items.insert(0, model);
    return model;
  }

  @override
  Future<({List<ComplaintModel> complaints, int total, int totalPages})> getMyComplaints({
    int page = 1,
    int limit = 10,
  }) async {
    if (shouldFail) {
      throw Exception('Simulated network error');
    }
    return (complaints: List<ComplaintModel>.from(items), total: items.length, totalPages: 1);
  }

  @override
  Future<ComplaintModel> getComplaintDetail(int id) async {
    if (shouldFail) {
      throw Exception('Simulated network error');
    }
    final item = items.firstWhere(
      (element) => element.id == id,
      orElse: () => throw Exception('Not found'),
    );
    return item;
  }

  static final Uint8List validPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
  ]);

  Uint8List? photoBytesResult;
  ComplaintPhotoException? photoError;

  @override
  Future<Uint8List> getComplaintPhotoBytes(String photoUrl) async {
    if (photoError != null) {
      throw photoError!;
    }
    if (shouldFail) {
      throw const ComplaintPhotoException('Gagal memuat foto: periksa koneksi jaringan Anda');
    }
    return photoBytesResult ?? validPngBytes;
  }

  @override
  Future<({List<ComplaintModel> complaints, int total, int totalPages, int page})> getAdminComplaints({
    String? status,
    String? category,
    String? officer,
    String? search,
    String? startDate,
    String? endDate,
    int page = 1,
    int limit = 10,
  }) async {
    return (complaints: List<ComplaintModel>.from(items), total: items.length, totalPages: 1, page: page);
  }

  @override
  Future<KanbanComplaintsData> getKanbanComplaints({
    String? category,
    String? officer,
    String? search,
    String? startDate,
    String? endDate,
  }) async {
    final menunggu = items.where((c) => c.status == ComplaintStatus.menunggu).toList();
    final diproses = items.where((c) => c.status == ComplaintStatus.diproses).toList();
    final selesai = items.where((c) => c.status == ComplaintStatus.selesai).toList();
    return KanbanComplaintsData(
      menunggu: menunggu,
      diproses: diproses,
      selesai: selesai,
      counts: {
        'Menunggu': menunggu.length,
        'Diproses': diproses.length,
        'Selesai': selesai.length,
        'Ditolak': items.where((c) => c.status == ComplaintStatus.ditolak).length,
      },
    );
  }

  @override
  Future<({ComplaintModel complaint, List<ComplaintAssignmentModel> assignments})> getAdminComplaintDetail(int id) async {
    final comp = await getComplaintDetail(id);
    return (complaint: comp, assignments: <ComplaintAssignmentModel>[]);
  }

  @override
  Future<({ComplaintModel complaint, List<ComplaintAssignmentModel> assignments})> assignOfficer({
    required int complaintId,
    required String officerName,
    int? officerUserId,
    String? notes,
    String? status,
  }) async {
    final comp = await getComplaintDetail(complaintId);
    final updated = comp.copyWith(
      assignedOfficer: officerName,
      assignedOfficerId: officerUserId,
      assignedAt: DateTime.now(),
      status: status != null ? ComplaintStatus.fromString(status) : null,
    );
    final idx = items.indexWhere((e) => e.id == complaintId);
    if (idx != -1) {
      items[idx] = updated;
    }
    final assignment = ComplaintAssignmentModel(
      id: 1,
      complaintId: complaintId,
      officerName: officerName,
      officerUserId: officerUserId,
      assignedBy: 1,
      assignedByName: 'Admin',
      notes: notes,
      assignedAt: DateTime.now(),
      createdAt: DateTime.now(),
    );
    return (complaint: updated, assignments: [assignment]);
  }

  @override
  Future<ComplaintModel> updateStatus({
    required int complaintId,
    required ComplaintStatus status,
  }) async {
    final comp = await getComplaintDetail(complaintId);
    final updated = comp.copyWith(status: status);
    final idx = items.indexWhere((e) => e.id == complaintId);
    if (idx != -1) {
      items[idx] = updated;
    }
    return updated;
  }

  @override
  Future<List<EligibleOfficerModel>> getEligibleOfficers() async {
    return [
      const EligibleOfficerModel(
        id: 10,
        name: 'Pak Joko (Teknisi)',
        role: 'SECURITY',
        phone: '08123456789',
        status: 'active',
      ),
    ];
  }

  @override
  Future<List<ComplaintAssignmentModel>> getAssignmentHistory(int complaintId) async {
    return [];
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  late FakeComplaintRepository fakeRepo;
  late ComplaintBloc bloc;
  late DioClient dioClient;

  setUp(() {
    fakeRepo = FakeComplaintRepository();
    bloc = ComplaintBloc(repository: fakeRepo);
    dioClient = DioClient(storageService: SecureStorageService());
  });

  tearDown(() {
    bloc.close();
  });

  group('Complaint Model and BLoC Tests', () {
    test('ComplaintCategory and ComplaintStatus parse correctly', () {
      expect(ComplaintCategory.fromString('Lampu Jalan'), ComplaintCategory.lampuJalan);
      expect(ComplaintCategory.fromString('Sampah'), ComplaintCategory.sampah);
      expect(ComplaintCategory.fromString('Ketertiban'), ComplaintCategory.ketertiban);
      expect(ComplaintCategory.fromString('Jalanan'), ComplaintCategory.jalanan);

      expect(ComplaintStatus.fromString('Menunggu'), ComplaintStatus.menunggu);
      expect(ComplaintStatus.fromString('Diproses'), ComplaintStatus.diproses);
      expect(ComplaintStatus.fromString('Selesai'), ComplaintStatus.selesai);
      expect(ComplaintStatus.fromString('Ditolak'), ComplaintStatus.ditolak);
    });

    test('ComplaintBloc loads empty complaints list successfully', () async {
      bloc.add(const LoadComplaintsEvent(page: 1));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ComplaintState>((s) => s.listStatus == ComplaintListStatus.loading),
          predicate<ComplaintState>((s) =>
              s.listStatus == ComplaintListStatus.success && s.complaints.isEmpty && s.totalComplaints == 0),
        ]),
      );
    });

    test('ComplaintBloc creates complaint and auto reloads list', () async {
      bloc.add(const CreateComplaintSubmittedEvent(
        title: 'Lampu jalan B1 padam',
        description: 'Padam sejak maghrib',
        category: ComplaintCategory.lampuJalan,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ComplaintState>((s) => s.submitStatus == ComplaintSubmitStatus.submitting),
          predicate<ComplaintState>((s) =>
              s.submitStatus == ComplaintSubmitStatus.success &&
              s.createdComplaint != null &&
              s.createdComplaint!.title == 'Lampu jalan B1 padam'),
          predicate<ComplaintState>((s) => s.listStatus == ComplaintListStatus.loading),
          predicate<ComplaintState>((s) =>
              s.listStatus == ComplaintListStatus.success && s.complaints.length == 1),
        ]),
      );
    });

    test('ComplaintBloc handles submission failure properly', () async {
      fakeRepo.shouldFail = true;
      bloc.add(const CreateComplaintSubmittedEvent(
        title: 'Sampah berserakan',
        description: 'TPS dekat taman penuh',
        category: ComplaintCategory.sampah,
      ));

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<ComplaintState>((s) => s.submitStatus == ComplaintSubmitStatus.submitting),
          predicate<ComplaintState>((s) => s.submitStatus == ComplaintSubmitStatus.failure),
        ]),
      );
    });
  });

  group('Lapor Cluster UI Tests', () {
    testWidgets('ResidentComplaintsScreen displays empty state with Lapor Cluster title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<DioClient>.value(
            value: dioClient,
            child: BlocProvider<ComplaintBloc>.value(
              value: bloc,
              child: const ResidentComplaintsScreen(),
            ),
          ),
        ),
      );

      // Trigger initial load and settle
      await tester.pumpAndSettle();

      // Check header and empty state
      expect(find.text('Lapor Cluster'), findsOneWidget);
      expect(find.text('Laporkan kendala fasilitas cluster ke pengelola cluster'), findsOneWidget);
      expect(find.text('Buat Laporan'), findsOneWidget);
    });

    testWidgets('CreateComplaintDialog form validation requires title and description', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider<ComplaintBloc>.value(
              value: bloc,
              child: const CreateComplaintDialog(),
            ),
          ),
        ),
      );

      // Submit with empty inputs
      final submitButton = find.text('Kirim Laporan');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Judul pengaduan cluster wajib diisi'), findsOneWidget);
      expect(find.text('Deskripsi pengaduan cluster wajib diisi'), findsOneWidget);
    });

    testWidgets('ResidentComplaintsScreen shows list item after creation and opens detail dialog', (tester) async {
      tester.view.physicalSize = const Size(1280, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Create new bloc instance with pre-seeded data
      final testRepo = FakeComplaintRepository();
      await testRepo.createComplaint(
        title: 'Jalanan Berlubang',
        description: 'Dekat tikungan pos satpam',
        category: ComplaintCategory.jalanan,
      );
      final testBloc = ComplaintBloc(repository: testRepo);
      addTearDown(() => testBloc.close());

      await tester.pumpWidget(
        MaterialApp(
          home: RepositoryProvider<DioClient>.value(
            value: dioClient,
            child: BlocProvider<ComplaintBloc>.value(
              value: testBloc,
              child: const ResidentComplaintsScreen(),
            ),
          ),
        ),
      );

      // Trigger initial load and wait for bloc stream emission
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Jalanan Berlubang'), findsOneWidget);
      expect(find.text('Dekat tikungan pos satpam'), findsOneWidget);
      expect(find.text('Menunggu'), findsOneWidget);

      // Tap card to open detail
      await tester.tap(find.text('Jalanan Berlubang'));
      await tester.pumpAndSettle();

      expect(find.text('Deskripsi Masalah'), findsOneWidget);
      expect(find.text('Tutup'), findsOneWidget);
    });

    testWidgets('ComplaintDetailDialog displays photo via Image.memory when successful', (tester) async {
      final complaintWithPhoto = ComplaintModel(
        id: 99,
        ticketNumber: 'TKT-20261027-PHOTO1',
        userId: 1,
        houseId: 10,
        title: 'Lampu Jalan Rusak',
        description: 'Lampu jalan padam total',
        category: ComplaintCategory.lampuJalan,
        photoUrl: '/api/v1/complaints/photo/lampu-rusak.jpg',
        status: ComplaintStatus.menunggu,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reporterName: 'Warga Boni',
        houseBlock: 'B1',
        houseNumber: '01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComplaintDetailDialog(
              complaint: complaintWithPhoto,
              dioClient: dioClient,
              complaintRepository: fakeRepo,
            ),
          ),
        ),
      );

      // Initially shows loading
      expect(find.text('Memuat foto pengaduan...'), findsOneWidget);

      // Settle loading
      await tester.pumpAndSettle();

      // Successfully displays Image.memory and hides loading
      expect(find.text('Memuat foto pengaduan...'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Foto Bukti Fasilitas Lingkungan'), findsOneWidget);
    });

    testWidgets('ComplaintDetailDialog displays distinct error on 403 Forbidden (Akses dilindungi)', (tester) async {
      fakeRepo.photoError = const ComplaintPhotoException('Akses dilindungi: Anda tidak memiliki izin melihat foto ini');

      final complaintWithPhoto = ComplaintModel(
        id: 100,
        ticketNumber: 'TKT-20261027-PHOTO2',
        userId: 1,
        houseId: 10,
        title: 'Sampah Menumpuk',
        description: 'Bau menyengat',
        category: ComplaintCategory.sampah,
        photoUrl: '/api/v1/complaints/photo/sampah.jpg',
        status: ComplaintStatus.menunggu,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reporterName: 'Warga Boni',
        houseBlock: 'B1',
        houseNumber: '01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComplaintDetailDialog(
              complaint: complaintWithPhoto,
              dioClient: dioClient,
              complaintRepository: fakeRepo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Akses dilindungi: Anda tidak memiliki izin melihat foto ini'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('ComplaintDetailDialog displays distinct error on 404 Not Found', (tester) async {
      fakeRepo.photoError = const ComplaintPhotoException('Foto pengaduan tidak ditemukan di server');

      final complaintWithPhoto = ComplaintModel(
        id: 101,
        ticketNumber: 'TKT-20261027-PHOTO3',
        userId: 1,
        houseId: 10,
        title: 'Jalan Rusak',
        description: 'Aspal terkelupas',
        category: ComplaintCategory.jalanan,
        photoUrl: '/api/v1/complaints/photo/jalan.jpg',
        status: ComplaintStatus.menunggu,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reporterName: 'Warga Boni',
        houseBlock: 'B1',
        houseNumber: '01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComplaintDetailDialog(
              complaint: complaintWithPhoto,
              dioClient: dioClient,
              complaintRepository: fakeRepo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Foto pengaduan tidak ditemukan di server'), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('ComplaintDetailDialog retry button triggers reloading', (tester) async {
      fakeRepo.photoError = const ComplaintPhotoException('Gagal memuat foto: periksa koneksi jaringan Anda');

      final complaintWithPhoto = ComplaintModel(
        id: 102,
        ticketNumber: 'TKT-20261027-PHOTO4',
        userId: 1,
        houseId: 10,
        title: 'Ketertiban Hewan',
        description: 'Anjing berkeliaran',
        category: ComplaintCategory.ketertiban,
        photoUrl: '/api/v1/complaints/photo/anjing.jpg',
        status: ComplaintStatus.menunggu,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        reporterName: 'Warga Boni',
        houseBlock: 'B1',
        houseNumber: '01',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComplaintDetailDialog(
              complaint: complaintWithPhoto,
              dioClient: dioClient,
              complaintRepository: fakeRepo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Gagal memuat foto: periksa koneksi jaringan Anda'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);

      // Now recover network
      fakeRepo.photoError = null;

      // Tap retry
      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      // Successfully displays Image
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Gagal memuat foto: periksa koneksi jaringan Anda'), findsNothing);
    });
  });
}
