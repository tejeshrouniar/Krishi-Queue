import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'core/theme/app_theme.dart';
import 'core/settings/app_preferences.dart';
import 'core/widgets/practice_banner.dart';
import 'features/auth/data/auth_service.dart';
import 'features/visit/data/visit_plan_store.dart';
import 'features/visit/presentation/visit_planner_screen.dart';
import 'features/issues/data/issue_notebook_store.dart';
import 'features/issues/presentation/issue_notebook_screen.dart';

import 'features/auth/domain/user_role.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/booking/presentation/booking_screen.dart';
import 'features/queue/presentation/track_queue_screen.dart';
import 'features/procurement/presentation/procurement_screen.dart';
import 'features/market/data/market_price_repository.dart';
import 'features/market/presentation/market_price_screen.dart';
import 'features/payment/presentation/payment_screen.dart';
import 'features/staff/presentation/staff_dashboard_screen.dart';
import 'features/driver/presentation/driver_dashboard_screen.dart';
import 'features/admin/presentation/admin_dashboard_screen.dart';
import 'features/ai_chat/data/ai_chat_api.dart';
import 'features/ai_chat/presentation/ai_chat_screen.dart';
import 'features/news/data/farmer_news_api.dart';
import 'features/news/presentation/news_screen.dart';

import 'features/booking/data/booking_repository_impl.dart';
import 'features/booking/data/demo_booking.dart';
import 'features/booking/domain/booking.dart';
import 'features/booking/domain/booking_repository.dart';

import 'features/queue/domain/queue_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPreferences.instance.load();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (error) {
    // Keep the app shell available when Firebase is not configured for the
    // current platform. The login screen reports that phone sign-in is off.
    debugPrint('Firebase initialization failed: $error');
  }

  runApp(const KrishiQueueApp());
}

class KrishiQueueApp extends StatelessWidget {
  const KrishiQueueApp({super.key});

  @override
  Widget build(BuildContext context) {
    final preferences = AppPreferences.instance;
    return AppPreferencesScope(
      preferences: preferences,
      child: AnimatedBuilder(
        animation: preferences,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Krishi Queue',
          theme: AppTheme.lightTheme(),
          locale: Locale(preferences.hindi ? 'hi' : 'en'),
          supportedLocales: const [Locale('hi'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) {
            final media = MediaQuery.of(context);
            // Respect device accessibility settings; the app toggle adds a larger
            // minimum without reducing the user's chosen system text size.
            final scale = media.textScaler.scale(1);
            return MediaQuery(
              data: media.copyWith(
                textScaler: preferences.largeText && scale < 1.25
                    ? const TextScaler.linear(1.25)
                    : media.textScaler,
              ),
              child: child!,
            );
          },
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserRole? _role;
  bool _restoring = true;
  bool _guest = false;
  AuthService? _authService;
  int _sessionGeneration = 0;
  final Map<String, VisitPlanStore> _visitStores = {};
  final Map<String, IssueNotebookStore> _issueStores = {};

  late BookingRepository _bookingRepository;
  late final MarketPriceRepositoryImpl _marketPriceRepository;
  late final GeminiAiChatApi _aiChatApi;
  late final FarmerNewsApi _farmerNewsApi;

  @override
  void initState() {
    super.initState();

    _bookingRepository = BookingRepositoryImpl(demoBooking);
    _marketPriceRepository = MarketPriceRepositoryImpl();
    _aiChatApi = GeminiAiChatApi();
    _farmerNewsApi = FarmerNewsApi();
    _authService = AuthService.tryCreate();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final generation = _sessionGeneration;
    UserRole? role;
    try {
      role = await _authService?.currentRole();
    } catch (_) {
      // Offline help remains available when a cached session needs refreshing.
    }
    if (mounted && generation == _sessionGeneration && !_guest) {
      setState(() {
        _role = role;
        _restoring = false;
      });
    }
  }

  @override
  void dispose() {
    _marketPriceRepository.dispose();
    _aiChatApi.dispose();
    _farmerNewsApi.dispose();
    super.dispose();
  }

  VisitPlanStore get _planStore {
    final owner = _guest
        ? 'guest'
        : (_authService?.auth.currentUser?.uid ?? 'guest');
    return _visitStores.putIfAbsent(owner, () => VisitPlanStore(owner: owner));
  }

  IssueNotebookStore get _issueStore {
    final owner = _guest
        ? 'guest'
        : (_authService?.auth.currentUser?.uid ?? 'guest');
    return _issueStores.putIfAbsent(
      owner,
      () => IssueNotebookStore(owner: owner),
    );
  }

  void _openIssues() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IssueNotebookScreen(store: _issueStore),
      ),
    );
  }

  void _continueOffline() => setState(() {
    _sessionGeneration++;
    _guest = true;
    _role = UserRole.farmer;
    _restoring = false;
  });

  void _openPlan() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VisitPlannerScreen(store: _planStore),
      ),
    );
  }

  void _handleLoginSuccess(UserRole role) {
    _sessionGeneration++;
    _authService ??= AuthService.tryCreate();
    setState(() {
      _role = role;
      _guest = false;
      _bookingRepository = BookingRepositoryImpl(demoBooking);
    });
  }

  Future<void> _logout() async {
    _sessionGeneration++;
    try {
      await _authService?.signOut();
    } catch (_) {
      if (!mounted) return;
      final p = AppPreferences.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            p.text(
              'Could not sign out. Please try again before sharing this phone.',
              'साइन आउट नहीं हो सका। फ़ोन देने से पहले फिर कोशिश करें।',
            ),
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _role = null;
      _guest = false;
      _bookingRepository = BookingRepositoryImpl(demoBooking);
    });
  }

  void _openBooking() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          child: BookingScreen(
            repository: _bookingRepository,
            marketPriceRepository: _marketPriceRepository,
            onBookingConfirmed: _openToken,
          ),
        ),
      ),
    );
  }

  void _openToken() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PracticePage(child: TokenScreen(repository: _bookingRepository)),
      ),
    );
  }

  void _openTrackQueue() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PracticePage(
          child: TrackQueueScreen(repository: _bookingRepository),
        ),
      ),
    );
  }

  void _openMarketPrice() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarketPriceScreen(repository: _marketPriceRepository),
      ),
    );
  }

  void _openPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PracticePage(child: PaymentScreen(repository: _bookingRepository)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _role;

    if (_restoring) {
      final p = AppPreferences.of(context);
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(p.text('Opening Krishi Queue…', 'कृषि क्यू खुल रहा है…')),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _continueOffline,
                  child: Text(
                    p.text('Use offline help now', 'अभी ऑफलाइन सहायता खोलें'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (role == null) {
      return LoginScreen(
        onLoginSuccess: _handleLoginSuccess,
        onContinueOffline: _continueOffline,
      );
    }

    switch (role) {
      case UserRole.farmer:
        return HomeScreen(
          key: ValueKey(_guest ? 'guest' : _authService?.auth.currentUser?.uid),
          repository: _bookingRepository,
          onBookSlot: _openBooking,
          onTokenTap: _openToken,
          onTrackQueueTap: _openTrackQueue,
          onMarketPriceTap: _openMarketPrice,
          onPaymentTap: _openPayment,
          newsScreen: NewsScreen(api: _farmerNewsApi),
          chatScreen: AiChatScreen(
            bookingRepository: _bookingRepository,
            marketPriceRepository: _marketPriceRepository,
            api: _aiChatApi,
          ),
          onLogout: _logout,
          onPlanVisit: _openPlan,
          onIssuesTap: _openIssues,
          issueStore: _issueStore,
          onClearIssueNotes: () => _issueStore.clear(),
          onClearLocalData: () => _planStore.clear(),
        );

      case UserRole.staff:
        return PracticePage(
          child: StaffDashboardScreen(
            repository: _bookingRepository,
            onLogout: _logout,
          ),
        );

      case UserRole.driver:
        return PracticePage(
          child: DriverDashboardScreen(
            repository: _bookingRepository,
            onLogout: _logout,
          ),
        );

      case UserRole.admin:
        return PracticePage(
          child: AdminDashboardScreen(
            repository: _bookingRepository,
            onLogout: _logout,
          ),
        );
    }
  }
}

class TokenScreen extends StatefulWidget {
  final BookingRepository repository;

  const TokenScreen({super.key, required this.repository});

  @override
  State<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends State<TokenScreen> {
  late final BookingRepository _repository;

  Booking? booking;

  @override
  void initState() {
    super.initState();

    _repository = widget.repository;

    _loadBooking();
  }

  Future<void> _loadBooking() async {
    final loadedBooking = await _repository.getBooking();

    if (!mounted) {
      return;
    }

    setState(() {
      booking = loadedBooking;
    });
  }

  Future<void> _advanceQueue() async {
    final currentBooking = booking;

    if (currentBooking == null) {
      return;
    }

    final updatedQueue = QueueEngine.advanceQueue(currentBooking.queueState);

    final updatedBooking = currentBooking.copyWith(queueState: updatedQueue);

    final savedBooking = await _repository.updateBooking(updatedBooking);

    if (!mounted) {
      return;
    }

    setState(() {
      booking = savedBooking;
    });
  }

  void _openProcurement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PracticePage(child: ProcurementScreen(repository: _repository)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentBooking = booking;

    if (currentBooking == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final queue = currentBooking.queueState;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Token',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadBooking,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text(
                    'PRACTICE TOKEN · NOT VALID FOR PROCUREMENT',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    queue.token,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: QrImageView(
                      data: 'KRISHI-QUEUE-PRACTICE-NOT-VALID:${queue.token}',
                      size: 190,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Queue',
                    value: '#${queue.queuePosition}',
                    icon: Icons.people_alt_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'ETA',
                    value: '${queue.estimatedWaitMinutes} min',
                    icon: Icons.access_time_rounded,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.storefront_outlined,
                      label: 'Centre',
                      value: queue.centre,
                    ),
                    _InfoRow(
                      icon: Icons.grass_outlined,
                      label: 'Crop',
                      value: queue.crop,
                    ),
                    _InfoRow(
                      icon: Icons.scale_outlined,
                      label: 'Quantity',
                      value: '${queue.quantityQuintals} Quintals',
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value: queue.deliveryDate,
                    ),
                    _InfoRow(
                      icon: Icons.access_time_outlined,
                      label: 'Slot',
                      value: queue.slot,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: InkWell(
                onTap: _openProcurement,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.timeline_rounded,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Procurement Status',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Gate → Weighing → Quality → Billing → Payment',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _advanceQueue,
              icon: const Icon(Icons.fast_forward_rounded),
              label: const Text('Simulate Queue Movement'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 21),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 11),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
