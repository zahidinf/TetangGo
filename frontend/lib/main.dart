import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/network/dio_client.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/announcements/data/announcements_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/billing/data/billing_repository.dart';
import 'features/cashbook/data/cashbook_repository.dart';
import 'features/home/data/dashboard_repository.dart';
import 'features/panic/data/panic_repository.dart';
import 'features/profile/data/profile_repository.dart';
import 'features/resident_management/data/resident_repository.dart';
import 'features/security/data/security_repository.dart';
import 'features/security/data/security_siren_service.dart';
import 'features/security/data/security_websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WAJIB: Inisialisasi locale bahasa Indonesia untuk DateFormat & NumberFormat
  await initializeDateFormatting('id_ID', null);

  final storageService = SecureStorageService();
  final dioClient = DioClient(storageService: storageService);
  final authRepository = AuthRepository(
    dio: dioClient.dio,
    storageService: storageService,
  );
  final residentRepository = ResidentRepository(dio: dioClient.dio);
  final profileRepository = ProfileRepository(dio: dioClient.dio);
  final billingRepository = BillingRepository(dioClient);
  final dashboardRepository = DashboardRepository(dio: dioClient.dio);
  final cashbookRepository = CashbookRepository(dioClient);
  final announcementsRepository = AnnouncementsRepository(dioClient);
  final panicRepository = PanicRepository(dioClient);
  final securityRepository = SecurityRepository(dioClient);
  final securityWsService =
      SecurityWebSocketService(storageService: storageService);
  final securitySirenService = SecuritySirenService();

  final authBloc = AuthBloc(authRepository: authRepository);

  runApp(TetangGoApp(
    dioClient: dioClient,
    authBloc: authBloc,
    authRepository: authRepository,
    residentRepository: residentRepository,
    profileRepository: profileRepository,
    billingRepository: billingRepository,
    dashboardRepository: dashboardRepository,
    cashbookRepository: cashbookRepository,
    announcementsRepository: announcementsRepository,
    panicRepository: panicRepository,
    securityRepository: securityRepository,
    securityWsService: securityWsService,
    securitySirenService: securitySirenService,
  ));
}

class TetangGoApp extends StatefulWidget {
  final DioClient dioClient;
  final AuthBloc authBloc;
  final AuthRepository authRepository;
  final ResidentRepository residentRepository;
  final ProfileRepository profileRepository;
  final BillingRepository billingRepository;
  final DashboardRepository dashboardRepository;
  final CashbookRepository cashbookRepository;
  final AnnouncementsRepository announcementsRepository;
  final PanicRepository panicRepository;
  final SecurityRepository securityRepository;
  final SecurityWebSocketService securityWsService;
  final SecuritySirenService securitySirenService;

  const TetangGoApp({
    super.key,
    required this.dioClient,
    required this.authBloc,
    required this.authRepository,
    required this.residentRepository,
    required this.profileRepository,
    required this.billingRepository,
    required this.dashboardRepository,
    required this.cashbookRepository,
    required this.announcementsRepository,
    required this.panicRepository,
    required this.securityRepository,
    required this.securityWsService,
    required this.securitySirenService,
  });

  @override
  State<TetangGoApp> createState() => _TetangGoAppState();
}

class _TetangGoAppState extends State<TetangGoApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.authBloc);
  }

  @override
  void dispose() {
    widget.securityWsService.dispose();
    widget.securitySirenService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<DioClient>.value(value: widget.dioClient),
        RepositoryProvider<AuthRepository>.value(value: widget.authRepository),
        RepositoryProvider<ResidentRepository>.value(
            value: widget.residentRepository),
        RepositoryProvider<ProfileRepository>.value(
            value: widget.profileRepository),
        RepositoryProvider<BillingRepository>.value(
            value: widget.billingRepository),
        RepositoryProvider<DashboardRepository>.value(
            value: widget.dashboardRepository),
        RepositoryProvider<CashbookRepository>.value(
            value: widget.cashbookRepository),
        RepositoryProvider<AnnouncementsRepository>.value(
            value: widget.announcementsRepository),
        RepositoryProvider<PanicRepository>.value(
            value: widget.panicRepository),
        RepositoryProvider<SecurityRepository>.value(
            value: widget.securityRepository),
        RepositoryProvider<SecurityWebSocketService>.value(
            value: widget.securityWsService),
        RepositoryProvider<SecuritySirenService>.value(
            value: widget.securitySirenService),
      ],
      child: BlocProvider<AuthBloc>.value(
        value: widget.authBloc,
        child: MaterialApp.router(
          title: 'TetangGo',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          routerConfig: _router,
        ),
      ),
    );
  }
}
