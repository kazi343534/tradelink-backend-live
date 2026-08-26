import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/api_service.dart';
import 'conversations_screen.dart';

const Color _dcPrimaryTeal = Color(0xFF0F766E);
const Color _dcScreenBg = Color(0xFFF8FAFC);
const Color _dcDarkText = Color(0xFF0F172A);
const Color _dcMutedText = Color(0xFF64748B);
const Color _dcBorderGray = Color(0xFFE2E8F0);

/// General-purpose direct chat between a Shop Owner and a Supplier.
class DirectChatScreen extends StatefulWidget {
  final String chatId;
  const DirectChatScreen({super.key, required this.chatId});

  @override
  State<DirectChatScreen> createState() => _DirectChatScreenState();
}

class _DirectChatScreenState extends State<DirectChatScreen> {
  Map<String, dynamic>? _chat;
  List<Map<String, dynamic>> _messages = [];
  String? _error;
  bool _sending = false;
  String _myRole = '';
  Timer? _pollTimer;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadMyContext();
    _fetchThread();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _fetchThread());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyContext() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _myRole = prefs.getString('user_role') ?? '');
  }

  bool get _isShopOwner => _myRole == 'shop_owner';

  bool _isMine(Map<String, dynamic> m) =>
      (m['senderType']?.toString() ?? '') ==
      (_isShopOwner ? 'SHOP_OWNER' : 'SUPPLIER');

  Future<void> _fetchThread() async {
    final data = await ApiService.get('/chats/${widget.chatId}/messages');
    if (data != null && mounted) {
      setState(() {
        _chat = Map<String, dynamic>.from(data['chat'] ?? {});
        _messages = List<Map<String, dynamic>>.from(data['messages'] ?? []);
        _error = null;
      });
      _scrollToBottom();
    } else if (mounted && _chat == null) {
      setState(() => _error = 'Failed to load conversation.');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final result = await ApiService.post(
        '/chats/${widget.chatId}/messages',
        body: {'textContent': text});
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (result != null) _inputController.clear();
    });
    if (result != null) {
      await _fetchThread();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to send'),
          backgroundColor: Color(0xFFEF4444)));
    }
  }

  /// Backend resolves the correct partner per viewer role
  /// (shop owner sees the supplier's business name, supplier sees the
  /// shop owner's business/full name). No hardcoded fallback names.
  String get _counterpartName {
    final v = _chat != null ? _chat!['counterpartName'] : null;
    final name = v?.toString().trim() ?? '';
    return name.isNotEmpty ? name : 'Chat';
  }

  String get _avatarInitial {
    final name = _counterpartName;
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length >= 2) {
      final initials =
          '${parts.first[0]}${parts.elementAt(1)[0]}'.toUpperCase();
      return initials;
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final productName = (_chat?['productName'] ?? '').toString();

    return Scaffold(
      backgroundColor: _dcScreenBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: _dcPrimaryTeal.withValues(alpha: 0.12),
              child: Text(
                _avatarInitial,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dcPrimaryTeal),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_counterpartName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _dcDarkText),
                      overflow: TextOverflow.ellipsis),
                  Row(children: [
                    Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Online',
                        style: TextStyle(
                            fontSize: 11, color: Color(0xFF10B981))),
                  ]),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF374151)),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const ConversationsScreen()),
              );
            }
          },
        ),
      ),
      body: Column(
        children: [
          if (productName.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFEEF8F6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                const Icon(Icons.inventory_2_outlined,
                    size: 14, color: _dcPrimaryTeal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('About: $productName',
                      style: const TextStyle(
                          fontSize: 12.5, color: _dcPrimaryTeal),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          Expanded(
            child: _error != null && _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!,
                            style:
                                const TextStyle(color: _dcMutedText)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _fetchThread,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: _dcPrimaryTeal,
                              foregroundColor: Colors.white),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) => _buildBubble(_messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> m) {
    final mine = _isMine(m);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: mine ? _dcPrimaryTeal : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 3),
            bottomRight: Radius.circular(mine ? 3 : 14),
          ),
          border: mine ? null : Border.all(color: _dcBorderGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(m['textContent'].toString(),
                style: TextStyle(
                    fontSize: 13.5,
                    color: mine ? Colors.white : _dcDarkText)),
            if (!mine &&
                (m['senderName'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(m['senderName'].toString(),
                    style: const TextStyle(
                        fontSize: 10.5, color: _dcMutedText)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _dcBorderGray)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Attachments',
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Attachments coming soon'),
                      behavior: SnackBarBehavior.floating)),
              icon: const Icon(Icons.attach_file_rounded,
                  size: 22, color: _dcMutedText),
            ),
            Expanded(
              child: TextField(
                controller: _inputController,
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Type a message\u2026',
                  hintStyle: const TextStyle(
                      fontSize: 13.5, color: Color(0xFF9CA3AF)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide:
                          BorderSide(color: _dcPrimaryTeal, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _send,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _dcPrimaryTeal,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _sending
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded,
                        size: 19, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
