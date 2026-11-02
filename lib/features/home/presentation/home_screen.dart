import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/practice_banner.dart';
import '../../booking/domain/booking.dart';
import '../../booking/domain/booking_repository.dart';
import '../../booking/domain/booking_status.dart';
import '../../booking/presentation/bookings_screen.dart';
import '../../help/presentation/help_screen.dart';
import '../../help/presentation/settings_screen.dart';
import '../../issues/data/issue_notebook_store.dart';

class HomeScreen extends StatefulWidget {
  final BookingRepository repository;
  final VoidCallback? onBookSlot;
  final VoidCallback? onTokenTap;
  final VoidCallback? onTrackQueueTap;
  final VoidCallback? onMarketPriceTap;
  final VoidCallback? onPaymentTap;
  final VoidCallback? onPlanVisit;
  final VoidCallback? onIssuesTap;
  final IssueNotebookStore? issueStore;
  final Future<void> Function()? onClearIssueNotes;
  final VoidCallback? onLogout;
  final Future<void> Function()? onClearLocalData;
  final Widget? newsScreen;
  final Widget? chatScreen;

  const HomeScreen({
    super.key,
    required this.repository,
    this.onBookSlot,
    this.onTokenTap,
    this.onTrackQueueTap,
    this.onMarketPriceTap,
    this.onPaymentTap,
    this.onPlanVisit,
    this.onIssuesTap,
    this.issueStore,
    this.onClearIssueNotes,
    this.onLogout,
    this.onClearLocalData,
    this.newsScreen,
    this.chatScreen,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final Set<int> _visitedTabs = {0};
  Booking? _booking;
  bool _loading = true;
  bool _loadFailed = false;
  bool _wasCurrent = false;
  int _loadGeneration = 0;
  int _issueGeneration = 0;
  int? _followUpsDue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_wasCurrent) _loadBooking();
    _wasCurrent = current;
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _loadBooking();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadBooking();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadBooking() async {
    _loadIssues();
    final generation = ++_loadGeneration;
    try {
      final booking = await widget.repository.getBooking();
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _booking = booking;
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _loadIssues() async {
    final generation = ++_issueGeneration;
    try {
      final issues = await widget.issueStore?.load();
      if (mounted && generation == _issueGeneration) {
        setState(() {
          _followUpsDue = issues
              ?.where((issue) => issue.needsFollowUp(DateTime.now()))
              .length;
        });
      }
    } catch (_) {
      if (mounted && generation == _issueGeneration) {
        setState(() => _followUpsDue = null);
      }
    }
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedTabs.add(index);
    });
    if (index == 0) _loadBooking();
  }

  Future<void> _openHelp() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HelpScreen(onOpenIssues: widget.onIssuesTap),
      ),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          onClearLocalData: widget.onClearLocalData,
          onClearIssueNotes: widget.onClearIssueNotes,
        ),
      ),
    );
    if (mounted) _loadBooking();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHome(p),
            // Mount each tab only when opened, avoiding hidden startup requests.
            _visitedTabs.contains(1)
                ? widget.newsScreen ?? const SizedBox.shrink()
                : const SizedBox.shrink(),
            _visitedTabs.contains(2)
                ? widget.chatScreen ?? const SizedBox.shrink()
                : const SizedBox.shrink(),
            if (_visitedTabs.contains(3))
              Column(
                children: [
                  const PracticeBanner(),
                  Expanded(
                    child: BookingsScreen(
                      repository: widget.repository,
                      onBookSlot: widget.onBookSlot,
                      onBookingTap: (_) => widget.onTokenTap?.call(),
                    ),
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home_rounded),
            label: p.text('Home', 'घर'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.newspaper_outlined),
            selectedIcon: const Icon(Icons.newspaper_rounded),
            label: p.text('News', 'समाचार'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.chat_bubble_outline),
            selectedIcon: const Icon(Icons.chat_bubble),
            label: p.text('Ask', 'पूछें'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.event_note_outlined),
            selectedIcon: const Icon(Icons.event_note),
            label: p.text('Practice', 'अभ्यास'),
          ),
        ],
      ),
    );
  }

  Widget _buildHome(AppPreferences p) => RefreshIndicator(
    onRefresh: _loadBooking,
    child: CustomScrollView(
      key: const PageStorageKey('farmer-home'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(p),
                    const SizedBox(height: 24),
                    _visitCard(p),
                    const SizedBox(height: 24),
                    Text(
                      p.text('Useful today', 'आज के काम की बातें'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    _actionCard(
                      icon: Icons.menu_book_outlined,
                      title: p.text(
                        'Help, even without internet',
                        'बिना इंटरनेट भी सहायता',
                      ),
                      subtitle: p.text(
                        'Documents, payments, complaints and helplines',
                        'कागज़, भुगतान, शिकायत और हेल्पलाइन',
                      ),
                      onTap: _openHelp,
                    ),
                    const SizedBox(height: 10),
                    _actionCard(
                      icon: Icons.chat_bubble_outline,
                      title: p.text('Ask a question', 'अपना सवाल पूछें'),
                      subtitle: p.text(
                        'Simple guidance in Hindi and English',
                        'हिन्दी और अंग्रेज़ी में आसान सहायता',
                      ),
                      onTap: () => _selectTab(2),
                    ),
                    const SizedBox(height: 10),
                    if (widget.onIssuesTap != null) ...[
                      _actionCard(
                        icon: Icons.assignment_outlined,
                        title: p.text('My follow-ups', 'मेरे फॉलो-अप'),
                        subtitle: _followUpsDue != null && _followUpsDue! > 0
                            ? p.text(
                                '$_followUpsDue personal follow-ups due · open notes',
                                '$_followUpsDue फॉलो-अप की तारीख आ गई · नोट खोलें',
                              )
                            : p.text(
                                'Keep problem notes, receipts checklist and next steps',
                                'समस्या के नोट, रसीद की सूची और अगला कदम रखें',
                              ),
                        onTap: widget.onIssuesTap,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _actionCard(
                      icon: Icons.currency_rupee,
                      title: p.text('Check mandi prices', 'मंडी के भाव देखें'),
                      subtitle: p.text(
                        'Compare the market and observation date',
                        'मंडी और भाव की तारीख मिलाकर देखें',
                      ),
                      onTap: widget.onMarketPriceTap,
                    ),
                    const SizedBox(height: 24),
                    _centreNotice(p),
                    const SizedBox(height: 24),
                    _practiceCard(p),
                    if (widget.onLogout != null) ...[
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout, size: 20),
                        label: Text(
                          p.text(
                            'Sign out / change account',
                            'लॉगआउट / खाता बदलें',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _header(AppPreferences p) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Icon(
            Icons.grass_rounded,
            size: 28,
            color: AppTheme.primaryGreen,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Krishi Queue',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          IconButton(
            onPressed: _openSettings,
            icon: const Icon(Icons.tune),
            tooltip: p.text('Language and settings', 'भाषा और सेटिंग'),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Text(
            p.text(
              'For farmers in Chhattisgarh',
              'छत्तीसगढ़ के किसानों के लिए',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          OutlinedButton.icon(
            onPressed: () => p.setHindi(!p.hindi),
            icon: const Icon(Icons.translate, size: 18),
            label: Text(p.hindi ? 'English' : 'हिन्दी'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(90, 44)),
          ),
        ],
      ),
    ],
  );

  Widget _visitCard(AppPreferences p) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppTheme.darkGreen,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.offline_pin_outlined,
              color: Color(0xffc9e7d5),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p.text('Preparation works offline', 'तैयारी बिना इंटरनेट भी'),
                style: const TextStyle(
                  color: Color(0xffc9e7d5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          p.text(
            'A little preparation.\nAn easier visit.',
            'पहले तैयारी।\nफिर केंद्र की यात्रा।',
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 29,
            height: 1.28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          p.text(
            'Keep your visit plan and checklist on this phone. Confirm your official token with the centre before leaving.',
            'यात्रा योजना और तैयारी की सूची इस फोन में रखें। निकलने से पहले केंद्र से सरकारी टोकन की पुष्टि करें।',
          ),
          style: const TextStyle(color: Color(0xffe2eee7), height: 1.5),
        ),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: widget.onPlanVisit ?? _openHelp,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xfff3f3dd),
            foregroundColor: AppTheme.darkGreen,
          ),
          icon: const Icon(Icons.checklist_outlined),
          label: Text(p.text('Plan my visit', 'यात्रा की तैयारी करें')),
        ),
      ],
    ),
  );

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 25),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    ),
  );

  Widget _centreNotice(AppPreferences p) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.paleGreen,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          p.text('Before paying for a vehicle', 'गाड़ी का किराया देने से पहले'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          p.text(
            'Ask your society: Is the centre open? Is my date confirmed? Which documents should I bring? Keep a paper copy of the official token.',
            'समिति से पूछें: केंद्र खुला है? मेरी तारीख पक्की है? कौन से कागज़ लाने हैं? सरकारी टोकन की कागज़ी प्रति रखें।',
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _openHelp,
          icon: const Icon(Icons.call_outlined, size: 18),
          label: Text(
            p.text('Help and official contacts', 'सहायता और सरकारी संपर्क'),
          ),
        ),
      ],
    ),
  );

  Widget _practiceCard(AppPreferences p) => Card(
    child: ExpansionTile(
      key: const PageStorageKey('practice-section'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      title: Text(
        p.text(
          'Try the procurement walkthrough',
          'खरीदी प्रक्रिया का अभ्यास करें',
        ),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(
        p.text(
          'Sample data · No government booking',
          'नमूना जानकारी · सरकारी बुकिंग नहीं',
        ),
      ),
      children: [
        const PracticeBanner(),
        const SizedBox(height: 14),
        if (_loading)
          const LinearProgressIndicator()
        else if (_loadFailed) ...[
          Text(
            p.text(
              'Could not load the practice record.',
              'अभ्यास की जानकारी नहीं खुली।',
            ),
          ),
          TextButton(
            onPressed: _loadBooking,
            child: Text(p.text('Try again', 'फिर कोशिश करें')),
          ),
        ] else if (_booking case final booking?) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              p.text(
                'Sample: ${booking.queueState.crop} · ${booking.quantityQtl} quintals',
                'नमूना: ${booking.queueState.crop} · ${booking.quantityQtl} क्विंटल',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (booking.status == BookingStatus.confirmed)
            TextButton.icon(
              onPressed: widget.onTokenTap,
              icon: const Icon(Icons.qr_code_2),
              label: Text(p.text('View practice token', 'अभ्यास टोकन देखें')),
            ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: widget.onBookSlot,
              child: Text(p.text('Try booking', 'बुकिंग अभ्यास')),
            ),
            OutlinedButton(
              onPressed: widget.onTrackQueueTap,
              child: Text(p.text('Sample queue', 'नमूना कतार')),
            ),
            OutlinedButton(
              onPressed: widget.onPaymentTap,
              child: Text(p.text('Sample payment', 'नमूना भुगतान')),
            ),
          ],
        ),
      ],
    ),
  );
}
