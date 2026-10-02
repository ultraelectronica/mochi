import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;

import '../config/app_config.dart';
import '../models/chat_session.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../services/stt_service.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/mochi_bottom_nav_bar.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.petProvider,
    required this.memberProvider,
    required this.onSendMessage,
    required this.onRefreshHistory,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.sttService,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final Future<void> Function(String text, {String inputType}) onSendMessage;
  final Future<void> Function() onRefreshHistory;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final SttService? sttService;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  late final SttService _stt;
  bool _isListening = false;
  bool _micBusy = false;
  bool _sending = false;
  bool _voiceDraft = false;
  bool _nearBottom = true;
  bool _followLatest = true;
  String? _failedDraft;
  String _failedInputType = 'text';
  String? _voiceError;
  String? _lastRenderedText;
  int? _lastSessionId;
  final FocusNode _composerFocus = FocusNode();
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _stt = widget.sttService ?? SttService();
    _scrollController = ScrollController()..addListener(_onScroll);
    _stt.onListeningChanged = (bool listening) {
      if (mounted) setState(() => _isListening = listening);
    };
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  void _onScroll() {
    final bool nearBottom = _scrollController.position.extentAfter < 100;
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      _followLatest = nearBottom;
    }
    if (nearBottom != _nearBottom && mounted) {
      setState(() => _nearBottom = nearBottom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    _stt.onListeningChanged = null;
    _stt.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    _followLatest = true;
    if (_scrollController.position.extentAfter < 1) return;
    _scrollController
        .animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        )
        .then((_) {
          if (mounted &&
              _followLatest &&
              _scrollController.hasClients &&
              _scrollController.position.extentAfter > 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
          }
        });
  }

  Future<void> _send({String inputType = 'text', String? retryText}) async {
    final String text = retryText ?? _controller.text.trim();
    if (text.isEmpty ||
        widget.petProvider.replyPending ||
        _sending ||
        _micBusy) {
      return;
    }
    if (_isListening) await _stt.stopListening();
    if (!mounted) return;
    final String source = retryText == null && _voiceDraft
        ? 'voice'
        : inputType;
    setState(() {
      _sending = true;
      _nearBottom = true;
      _followLatest = true;
      if (retryText == null) _voiceDraft = false;
    });
    if (retryText == null || _controller.text.trim() == retryText) {
      _controller.clear();
      _voiceDraft = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    bool failed = false;
    try {
      await widget.onSendMessage(text, inputType: source);
      failed = widget.petProvider.errorMessage != null;
    } catch (_) {
      failed = true;
    } finally {
      if (mounted) {
        _failedDraft = failed ? text : null;
        _failedInputType = source;
        if (failed && _controller.text.isEmpty) {
          _controller.text = text;
          _voiceDraft = source == 'voice';
        }
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _toggleMic() async {
    if (_micBusy || _sending) return;
    setState(() {
      _micBusy = true;
      _voiceError = null;
    });
    try {
      if (_isListening) {
        await _stt.stopListening();
      } else {
        final bool available = await _stt.initialize();
        if (!mounted) return;
        if (!available) {
          setState(
            () => _voiceError =
                'Voice input is unavailable. Check microphone and speech permissions in your phone settings, or type a message.',
          );
          return;
        }
        final String draft = _controller.text.trimRight();
        _composerFocus.unfocus();
        await _stt.startListening(
          onResult: (String result) {
            if (!mounted || result.trim().isEmpty) return;
            final String text = '${draft.isEmpty ? '' : '$draft '}$result';
            _controller.value = TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            );
            setState(() => _voiceDraft = true);
          },
          onError: (String message) {
            if (mounted) setState(() => _voiceError = message);
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _voiceError =
              'Voice input could not start. Try again or type your message.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _micBusy = false;
          _isListening = _stt.isListening;
        });
      }
    }
  }

  void _fillStarter(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _composerFocus.requestFocus();
  }

  void _openOptions() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) => SafeArea(
        child: AnimatedBuilder(
          animation: widget.petProvider,
          builder: (BuildContext context, Widget? child) =>
              SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Chat options',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Read replies aloud'),
                      subtitle: const Text(
                        'Hear Mochi’s replies on this device.',
                      ),
                      value: widget.petProvider.ttsEnabled,
                      onChanged: widget.petProvider.setTtsEnabled,
                    ),
                    SwitchListTile(
                      title: const Text('Deep think'),
                      subtitle: const Text(
                        'Give Mochi more time to ponder before replying.',
                      ),
                      value: widget.petProvider.thinkEnabled,
                      onChanged: widget.petProvider.replyPending
                          ? null
                          : widget.petProvider.setThinkEnabled,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Future<void> _refreshHistory() async {
    if (widget.petProvider.replyPending) return;
    await widget.onRefreshHistory();
  }

  void _openSessionsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) =>
          _ChatSessionsSheet(petProvider: widget.petProvider),
    );
  }

  String _dateLabel(DateTime when) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime that = DateTime(when.year, when.month, when.day);
    final int diff = today.difference(that).inDays;
    if (diff == 0) {
      return 'Today';
    }
    if (diff == 1) {
      return 'Yesterday';
    }
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[when.month - 1]} ${when.day}';
  }

  bool _isNewDay(DateTime a, DateTime b) {
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  @override
  Widget build(BuildContext context) {
    final Pet pet = widget.petProvider.pet;
    final Member currentMember = widget.memberProvider.currentMember;
    final List<ChatEntry> entries = widget.petProvider.chatEntries;
    final String renderedText =
        '${entries.length}:${entries.isEmpty ? '' : entries.last.text}';
    final bool sessionChanged =
        _lastSessionId != widget.petProvider.activeSessionId;
    _lastSessionId = widget.petProvider.activeSessionId;
    if (renderedText != _lastRenderedText || sessionChanged) {
      _lastRenderedText = renderedText;
      if (entries.isNotEmpty && (_followLatest || sessionChanged)) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    }

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: MochiPalette.card,
            borderRadius: BorderRadius.circular(20),
          ),
          child: _ExpandedChatHeader(
            pet: pet,
            isFullscreen: widget.isFullscreen,
            onToggleFullscreen: widget.onToggleFullscreen,
            onOpenSessions: _openSessionsSheet,
            onOpenOptions: _openOptions,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: RepaintBoundary(
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: RefreshIndicator(
                    onRefresh: _refreshHistory,
                    child:
                        widget.petProvider.chatEntries.isEmpty &&
                            !widget.petProvider.replyPending
                        ? ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                            children: <Widget>[
                              _EmptyChatIntro(
                                pet: pet,
                                onStarter: _fillStarter,
                              ),
                            ],
                          )
                        : ListView(
                            controller: _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            children: <Widget>[
                              for (int index = 0; index < _itemCount(); index++)
                                _buildListItem(index, currentMember, pet),
                            ],
                          ),
                  ),
                ),
                if (!_nearBottom && entries.isNotEmpty)
                  Positioned(
                    bottom: 8,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _scrollToEnd,
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 18,
                        ),
                        label: const Text('Jump to latest'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.petProvider.errorMessage != null ||
            _failedDraft != null) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: pixelCardDecoration(MochiPalette.peach),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.sync_problem_rounded,
                  color: MochiPalette.ink,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.petProvider.errorMessage ??
                        'Your message could not be sent. Your draft is saved; try again.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 6),
                if (_failedDraft != null && !widget.petProvider.replyPending)
                  TextButton(
                    onPressed: _sending
                        ? null
                        : () => _send(
                            retryText: _failedDraft,
                            inputType: _failedInputType,
                          ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: const Size(48, 48),
                    ),
                    child: const Text('Resend'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (_voiceError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _voiceError!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        _Composer(
          controller: _controller,
          focusNode: _composerFocus,
          isListening: _isListening,
          micEnabled: !_micBusy && !_sending,
          replyPending: widget.petProvider.replyPending || _sending,
          onSend: _send,
          onToggleMic: _toggleMic,
        ),
        SizedBox(
          height:
              widget.isFullscreen || MediaQuery.viewInsetsOf(context).bottom > 0
              ? 14
              : MochiBottomNavBar.overlayPadding(context) + 24,
        ),
      ],
    );
  }

  int _itemCount() {
    final List<ChatEntry> entries = widget.petProvider.chatEntries;
    // The streaming Mochi entry already lives in chatEntries; no extra slot.
    return entries.length + _dateChipCount();
  }

  int _dateChipCount() {
    final List<ChatEntry> entries = widget.petProvider.chatEntries;
    if (entries.isEmpty) {
      return 0;
    }
    int count = 1;
    for (int i = 1; i < entries.length; i++) {
      if (_isNewDay(entries[i - 1].createdAt, entries[i].createdAt)) {
        count += 1;
      }
    }
    return count;
  }

  Widget _buildListItem(int index, Member currentMember, Pet pet) {
    final List<ChatEntry> entries = widget.petProvider.chatEntries;
    final bool replyPending = widget.petProvider.replyPending;
    int i = 0;
    int entryIndex = 0;
    while (entryIndex < entries.length) {
      if (entryIndex == 0) {
        if (index == i) {
          return _DateChip(label: _dateLabel(entries[0].createdAt));
        }
        i += 1;
      } else {
        final bool dayChanged = _isNewDay(
          entries[entryIndex - 1].createdAt,
          entries[entryIndex].createdAt,
        );
        if (dayChanged) {
          if (index == i) {
            return _DateChip(label: _dateLabel(entries[entryIndex].createdAt));
          }
          i += 1;
        }
      }
      if (index == i) {
        final ChatEntry curr = entries[entryIndex];
        final bool isFirst = entryIndex == 0;
        final ChatEntry? prev = isFirst ? null : entries[entryIndex - 1];
        final bool showMeta =
            isFirst ||
            (prev!.isPet != curr.isPet) ||
            (prev.author != curr.author) ||
            _isNewDay(prev.createdAt, curr.createdAt);
        // While Mochi is still waiting for the first token, the pending
        // stream entry is empty — show the typing avatar instead of a
        // hollow bubble. Once tokens arrive it becomes a normal bubble.
        final bool awaitingFirstToken =
            replyPending &&
            entryIndex == entries.length - 1 &&
            curr.isPet &&
            curr.text.isEmpty;
        if (awaitingFirstToken) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TypingAvatar(pet: pet, breath: _breath),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChatBubble(
            entry: curr,
            currentMember: currentMember,
            petProvider: widget.petProvider,
            showAuthor: showMeta,
            showTimestamp: showMeta,
          ),
        );
      }
      i += 1;
      entryIndex += 1;
    }
    return const SizedBox.shrink();
  }
}

class _ExpandedChatHeader extends StatelessWidget {
  const _ExpandedChatHeader({
    required this.pet,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onOpenSessions,
    required this.onOpenOptions,
  });

  final Pet pet;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback onOpenSessions;
  final VoidCallback onOpenOptions;

  @override
  Widget build(BuildContext context) {
    final Widget actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _IconAction(
          icon: Icons.history_rounded,
          tooltip: 'Chat history',
          onPressed: onOpenSessions,
        ),
        if (onToggleFullscreen != null)
          _IconAction(
            icon: isFullscreen
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded,
            tooltip: isFullscreen ? 'Exit fullscreen' : 'Fullscreen chat',
            onPressed: onToggleFullscreen!,
          ),
        _IconAction(
          icon: Icons.more_horiz_rounded,
          tooltip: 'Chat options',
          onPressed: onOpenOptions,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool stacked =
            constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(18) > 24;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                MochiPetAvatar(pet: pet, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Mochi',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Feeling ${pet.mood.label.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (!stacked) actions,
              ],
            ),
            if (stacked)
              Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      },
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, size: 22, color: MochiPalette.ink),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: MochiPalette.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: MochiPalette.ink, width: 1.5),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              color: MochiPalette.ink.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypingAvatar extends StatelessWidget {
  const _TypingAvatar({required this.pet, required this.breath});

  final Pet pet;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    final MochiMood mood = pet.mood;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        AnimatedBuilder(
          animation: breath,
          builder: (BuildContext context, Widget? child) {
            final double pulse = 1 + (breath.value * 0.06);
            final double opacity = 0.85 + (breath.value * 0.15);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(scale: pulse, child: child),
            );
          },
          child: MochiPetAvatar(pet: pet, size: 32),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: mood.color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: MochiPalette.ink, width: 2),
          ),
          child: Text(
            'Mochi is thinking…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: MochiPalette.ink.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyChatIntro extends StatelessWidget {
  const _EmptyChatIntro({required this.pet, required this.onStarter});

  final Pet pet;
  final ValueChanged<String> onStarter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          MochiPetAvatar(pet: pet, size: 72),
          const SizedBox(height: 14),
          Text(
            'What’s on your mind?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'A little joy, a tough day, or just a hello. Mochi is here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String starter in <String>[
                'Something good happened',
                'I’ve had a tough day',
                'Let’s chat',
              ])
                OutlinedButton(
                  onPressed: () => onStarter(starter),
                  child: Text(starter, textAlign: TextAlign.center),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Everything stays on this phone.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              color: MochiPalette.ink.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.isListening,
    required this.micEnabled,
    required this.replyPending,
    required this.onSend,
    required this.onToggleMic,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isListening;
  final bool micEnabled;
  final bool replyPending;
  final Future<void> Function({String inputType}) onSend;
  final VoidCallback onToggleMic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MochiPalette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: controller,
            focusNode: focusNode,
            minLines: 1,
            maxLines: 4,
            readOnly: isListening,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
            decoration: InputDecoration(
              hintText: isListening ? 'Listening…' : 'Message Mochi…',
              hintStyle: const TextStyle(color: Color(0xFF596177)),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 8,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              IconButton(
                onPressed: micEnabled ? onToggleMic : null,
                icon: Icon(
                  isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                ),
                color: MochiPalette.ink,
                style: IconButton.styleFrom(
                  backgroundColor: isListening
                      ? MochiPalette.lightPink
                      : MochiPalette.background,
                  minimumSize: const Size(48, 48),
                ),
                tooltip: isListening
                    ? 'Stop recording'
                    : 'Record a voice draft',
              ),
              const SizedBox(width: 8),
              const Spacer(),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder:
                    (
                      BuildContext context,
                      TextEditingValue value,
                      Widget? child,
                    ) => FilledButton.icon(
                      onPressed:
                          replyPending ||
                              isListening ||
                              value.text.trim().isEmpty
                          ? null
                          : onSend,
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Send'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
              ),
            ],
          ),
          if (isListening || replyPending)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                isListening
                    ? 'Tap stop to review your voice draft.'
                    : 'Mochi is replying. You can draft your next message.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatSessionsSheet extends StatefulWidget {
  const _ChatSessionsSheet({required this.petProvider});

  final PetProvider petProvider;

  @override
  State<_ChatSessionsSheet> createState() => _ChatSessionsSheetState();
}

class _ChatSessionsSheetState extends State<_ChatSessionsSheet> {
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      await widget.petProvider.loadSessions();
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(ChatSession session) async {
    if (widget.petProvider.replyPending) return;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: pixelCardDecoration(MochiPalette.peach),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Delete chat?',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This removes "${session.title}" and its messages. This cannot be undone.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: TextButton.styleFrom(
                          foregroundColor: MochiPalette.ink.withValues(
                            alpha: 0.7,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Pixelify Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: MochiPalette.peach,
                          foregroundColor: MochiPalette.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          textStyle: const TextStyle(
                            fontFamily: 'Pixelify Sans',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: const BorderSide(
                              color: MochiPalette.ink,
                              width: 2.5,
                            ),
                          ),
                        ),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.petProvider.deleteSession(session.id);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.petProvider,
      builder: (BuildContext context, Widget? child) {
        final List<ChatSession> sessions = widget.petProvider.sessions;
        final int? activeId = widget.petProvider.activeSessionId;

        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            decoration: pixelCardDecoration(MochiPalette.cloudBlue),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: MochiPalette.ink.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.forum_rounded, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Chats',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (_loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Close',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New chat'),
                      onPressed: widget.petProvider.replyPending
                          ? null
                          : () {
                              widget.petProvider.startNewSession();
                              Navigator.of(context).pop();
                            },
                    ),
                  ),
                  if (widget.petProvider.replyPending)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'You can switch chats once Mochi finishes replying.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: sessions.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 32,
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 36,
                                      color: MochiPalette.ink.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'No saved chats yet',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Start a new chat above. It saves once you send a message.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontSize: 12,
                                            color: MochiPalette.ink.withValues(
                                              alpha: 0.55,
                                            ),
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : RefreshIndicator(
                            onRefresh: _reload,
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              shrinkWrap: true,
                              itemCount: sessions.length,
                              separatorBuilder:
                                  (BuildContext context, int index) =>
                                      const SizedBox(height: 8),
                              itemBuilder: (BuildContext context, int index) {
                                final ChatSession session = sessions[index];
                                return _SessionTile(
                                  session: session,
                                  isActive: session.id == activeId,
                                  onSelect: widget.petProvider.replyPending
                                      ? null
                                      : () {
                                          widget.petProvider
                                              .selectSession(session.id)
                                              .catchError((Object _) {});
                                          Navigator.of(context).pop();
                                        },
                                  onDelete: widget.petProvider.replyPending
                                      ? null
                                      : () => _confirmDelete(session),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onSelect,
    required this.onDelete,
  });

  final ChatSession session;
  final bool isActive;
  final VoidCallback? onSelect;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? MochiPalette.mint.withValues(alpha: 0.6) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MochiPalette.ink, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isActive ? MochiPalette.mint : MochiPalette.cloudBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: MochiPalette.ink, width: 1.5),
                ),
                child: Icon(
                  isActive
                      ? Icons.chat_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 15,
                  color: MochiPalette.ink,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      session.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.preview.isEmpty
                          ? 'No messages yet'
                          : session.preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: MochiPalette.ink.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${session.memberName} \u00b7 ${session.messageCount} '
                      '${session.messageCount == 1 ? "turn" : "turns"} \u00b7 '
                      '${session.timestamp}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        color: MochiPalette.ink.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: MochiPalette.ink.withValues(alpha: 0.6),
                ),
                tooltip: 'Delete chat',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
