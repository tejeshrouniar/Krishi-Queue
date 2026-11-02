import 'package:flutter/material.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/network/krishi_gateway.dart';
import '../../../core/theme/app_theme.dart';
import '../../booking/domain/booking_repository.dart';
import '../../market/data/market_price_repository.dart';
import '../data/ai_chat_api.dart';
import '../data/ai_chat_models.dart';
import '../domain/chat_message.dart';
import '../domain/offline_assistant.dart';
import 'widgets/chat_input.dart';
import 'widgets/chat_message_bubble.dart';

class AiChatScreen extends StatefulWidget {
  final BookingRepository bookingRepository;
  final MarketPriceRepository marketPriceRepository;
  final GeminiAiChatApi api;
  const AiChatScreen({
    super.key,
    required this.bookingRepository,
    required this.marketPriceRepository,
    required this.api,
  });
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;
  String? _lastQuestion;
  String? _notice;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _append(String text, {bool user = false}) {
    _messages.add(
      ChatMessage(
        role: user ? ChatMessageRole.user : ChatMessageRole.assistant,
        text: text,
        timestamp: DateTime.now(),
      ),
    );
    if (_messages.length > 40) _messages.removeRange(0, _messages.length - 40);
  }

  void _sendLocal(String question) {
    final text = question.trim();
    if (text.isEmpty || _sending) return;
    final prefs = AppPreferences.of(context);
    setState(() {
      _lastQuestion = text;
      _notice = null;
      _append(text, user: true);
      _append(OfflineAssistant.answer(text, hindi: prefs.hindi));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<bool> _consent({required bool translation}) async {
    final p = AppPreferences.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(
              translation
                  ? p.text(
                      'Translate with BHASHINI?',
                      'BHASHINI से अनुवाद करें?',
                    )
                  : p.text('Ask online?', 'ऑनलाइन पूछें?'),
            ),
            content: Text(
              translation
                  ? p.text(
                      'This answer will be sent to BHASHINI for translation. It uses internet. Machine translations can contain mistakes; keep the original for official details.',
                      'यह उत्तर अनुवाद के लिए BHASHINI को भेजा जाएगा। इसमें इंटरनेट लगेगा। मशीन अनुवाद में गलती हो सकती है; आधिकारिक जानकारी के लिए मूल पाठ रखें।',
                    )
                  : p.text(
                      'Only your latest question goes to the online assistant. Do not include phone numbers, Aadhaar, OTPs or bank details. This answer is general guidance, not an official decision.',
                      'केवल आपका आखिरी सवाल ऑनलाइन सहायक को भेजा जाएगा। फोन नंबर, आधार, OTP या बैंक विवरण न लिखें। उत्तर सामान्य मार्गदर्शन है, आधिकारिक निर्णय नहीं।',
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(p.text('Keep offline', 'ऑफलाइन रहें')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(p.text('Continue', 'आगे बढ़ें')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _online({bool translation = false}) async {
    if (_sending || _lastQuestion == null) return;
    final p = AppPreferences.of(context);
    if (!widget.api.configured) {
      setState(
        () => _notice = p.text(
          'Online help and BHASHINI are not connected yet. Hindi and English saved help work without internet.',
          'ऑनलाइन मदद और BHASHINI अभी जुड़े नहीं हैं। हिंदी और अंग्रेज़ी की सहेजी मदद बिना इंटरनेट चलती है।',
        ),
      );
      return;
    }
    if (!await _consent(translation: translation) || !mounted) return;
    setState(() {
      _sending = true;
      _notice = null;
    });
    try {
      String result;
      if (translation) {
        final sourceText = _messages.lastWhere((m) => !m.isUser).text;
        final source = RegExp(r'[\u0900-\u097F]').hasMatch(sourceText)
            ? 'hi'
            : 'en';
        result = await widget.api.translate(
          sourceText,
          source: source,
          target: source == 'hi' ? 'en' : 'hi',
        );
      } else {
        result = (await widget.api.send(
          AiChatRequest(
            history: const [],
            message: _lastQuestion!,
            appContext: '',
          ),
        )).text;
      }
      if (!mounted) return;
      setState(() {
        _append(
          '${translation ? p.text('BHASHINI translation', 'BHASHINI अनुवाद') : p.text('Online guidance · verify official details', 'ऑनलाइन मार्गदर्शन · आधिकारिक जानकारी जाँचें')}\n\n$result',
        );
      });
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _notice = error is GatewayException
            ? error.localizedMessage(hindi: p.hindi)
            : p.text(
                'Could not connect to online help. Sign in and try again when the connection improves. Your offline answer is kept.',
                'ऑनलाइन मदद से संपर्क नहीं हुआ। साइन-इन करके बेहतर नेटवर्क पर दोबारा कोशिश करें। ऑफलाइन उत्तर सुरक्षित है।',
              ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPreferences.of(context);
    final suggestions = [
      p.text('Prepare my visit', 'यात्रा की तैयारी'),
      p.text('Official token', 'आधिकारिक टोकन'),
      p.text('Payment delayed', 'भुगतान में देरी'),
      p.text('Mandi prices', 'मंडी भाव'),
      p.text('Schemes', 'सरकारी योजनाएँ'),
      p.text('Crop disease advice', 'फसल की बीमारी'),
    ];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.text('Farmer help', 'किसान सहायता'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      p.text(
                        'Basic answers work offline',
                        'सामान्य जवाब बिना इंटरनेट',
                      ),
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: p.text(
                  'Clear chat from this phone',
                  'इस फोन से चैट साफ करें',
                ),
                onPressed: _sending || _messages.isEmpty
                    ? null
                    : () => setState(() {
                        _messages.clear();
                        _lastQuestion = null;
                        _notice = null;
                      }),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (_messages.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    p.text(
                      'Ask about preparing your visit, payment delays or where to get reliable help. No sign-in is needed for these saved answers. Please do not share personal documents.',
                      'यात्रा की तैयारी, भुगतान में देरी या भरोसेमंद मदद के बारे में पूछें। इन सहेजे जवाबों के लिए साइन-इन जरूरी नहीं। निजी दस्तावेज साझा न करें।',
                    ),
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ..._messages.map((m) => ChatMessageBubble(message: m)),
              if (_sending)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      p.text(
                        'Connecting… Your saved help stays available.',
                        'संपर्क हो रहा है… सहेजी मदद उपलब्ध है।',
                      ),
                    ),
                  ),
                ),
              if (_notice != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _notice!,
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: suggestions
                    .map(
                      (s) => ActionChip(
                        label: Text(s),
                        onPressed: _sending ? null : () => _sendLocal(s),
                      ),
                    )
                    .toList(),
              ),
              if (_lastQuestion != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _sending ? null : () => _online(),
                      icon: const Icon(Icons.cloud_outlined),
                      label: Text(p.text('Ask online', 'ऑनलाइन पूछें')),
                    ),
                    TextButton.icon(
                      onPressed: _sending
                          ? null
                          : () => _online(translation: true),
                      icon: const Icon(Icons.translate),
                      label: Text(
                        p.text('BHASHINI translation', 'BHASHINI अनुवाद'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        ChatInput(enabled: !_sending, onSend: _sendLocal),
      ],
    );
  }
}
