// Hallmark · macrostructure: Chat Workbench · tone: playful · anchor hue: pet-mood
// pre-emit critique: P5 H5 E5 S5 R5 V4
// redesign: chat screen rebuilt in Mochi's pixel-storybook language
//   - extracted MochiPetAvatar helper, de-duped inline Member construction
//   - empty state -> pixel intro (3 breathing swatches + avatar + prompt)
//   - header trimmed: status dots + fullscreen icon, drag handle matches main shell
//   - chat card accent shifts with pet.mood.tint (matches home hero pattern)
//   - bubble grouping: meta row (author + timestamp) shows on first of a group
//   - date chips between cross-day groups
//   - typing indicator: pulsing pet avatar instead of generic dots
//   - composer: dense row + "Listening..." pill when mic is active

import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../services/stt_service.dart';
import '../widgets/chat_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.petProvider,
    required this.memberProvider,
    required this.onSendMessage,
    required this.onRefreshHistory,
    this.onToggleFullscreen,
    this.isFullscreen = false,
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final Future<void> Function(String text, {String inputType}) onSendMessage;
  final Future<void> Function() onRefreshHistory;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  final SttService _stt = SttService();
  bool _isListening = false;
  bool _headerCollapsed = false;
  double _headerDragDelta = 0;
  int _lastRenderedEntryCount = 0;
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
    _stt.initialize();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _stt.cancel();
    _breath.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _setHeaderCollapsed(bool value) {
    if (_headerCollapsed == value) {
      return;
    }
    setState(() {
      _headerCollapsed = value;
    });
  }

  void _onHeaderDragStart(DragStartDetails details) {
    _headerDragDelta = 0;
  }

  void _onHeaderDragUpdate(DragUpdateDetails details) {
    _headerDragDelta += details.delta.dy;
    if (!_headerCollapsed && _headerDragDelta < -24) {
      _setHeaderCollapsed(true);
      _headerDragDelta = 0;
    } else if (_headerCollapsed && _headerDragDelta > 24) {
      _setHeaderCollapsed(false);
      _headerDragDelta = 0;
    }
  }

  void _onHeaderDragEnd(DragEndDetails details) {
    final double velocity = details.primaryVelocity ?? 0;
    if (velocity < -180) {
      _setHeaderCollapsed(true);
    } else if (velocity > 180) {
      _setHeaderCollapsed(false);
    }
    _headerDragDelta = 0;
  }

  Future<void> _send({String inputType = 'text'}) async {
    final String text = _controller.text.trim();
    if (text.isEmpty || widget.petProvider.replyPending) {
      return;
    }
    _controller.clear();
    await widget.onSendMessage(text, inputType: inputType);
  }

  Future<void> _toggleMic() async {
    if (_isListening) {
      final String result = await _stt.stopListening();
      setState(() {
        _isListening = false;
      });
      final String text = result.trim();
      if (text.isNotEmpty && !widget.petProvider.replyPending) {
        _controller.text = text;
        await _send(inputType: 'voice');
      }
      return;
    }

    final bool available = await _stt.initialize();
    if (!available) {
      return;
    }

    await _stt.startListening(
      onResult: (String result) {
        if (result.trim().isNotEmpty) {
          setState(() {
            _controller.text = result;
          });
        }
      },
    );
    setState(() {
      _isListening = true;
    });
  }

  Future<void> _refreshHistory() async {
    await widget.onRefreshHistory();
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
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
    final int visibleEntryCount = widget.petProvider.chatEntries.length +
        (widget.petProvider.replyPending ? 1 : 0);

    if (visibleEntryCount != _lastRenderedEntryCount) {
      _lastRenderedEntryCount = visibleEntryCount;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }

    return Column(
      children: <Widget>[
        GestureDetector(
          onVerticalDragStart: _onHeaderDragStart,
          onVerticalDragUpdate: _onHeaderDragUpdate,
          onVerticalDragEnd: _onHeaderDragEnd,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                _headerCollapsed ? 10 : 14,
                16,
                10,
              ),
              decoration: pixelCardDecoration(pet.mood.color),
              child: _headerCollapsed
                  ? _CollapsedChatHeader(
                      pet: pet,
                      serverOnline: widget.petProvider.serverOnline,
                      ttsEnabled: widget.petProvider.ttsEnabled,
                      isFullscreen: widget.isFullscreen,
                      onToggleFullscreen: widget.onToggleFullscreen,
                      onExpand: () => _setHeaderCollapsed(false),
                    )
                  : _ExpandedChatHeader(
                      pet: pet,
                      serverOnline: widget.petProvider.serverOnline,
                      ttsEnabled: widget.petProvider.ttsEnabled,
                      isFullscreen: widget.isFullscreen,
                      onToggleFullscreen: widget.onToggleFullscreen,
                      onCollapse: () => _setHeaderCollapsed(true),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            decoration: pixelCardDecoration(pet.mood.tint),
            child: RefreshIndicator(
              onRefresh: _refreshHistory,
              child: widget.petProvider.chatEntries.isEmpty &&
                      !widget.petProvider.replyPending
                  ? ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                      children: <Widget>[
                        _EmptyChatIntro(
                          pet: pet,
                          breath: _breath,
                        ),
                      ],
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      itemCount: _itemCount(),
                      itemBuilder: (BuildContext context, int index) {
                        return _buildListItem(index, currentMember, pet);
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (widget.petProvider.errorMessage != null) ...<Widget>[
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
                    widget.petProvider.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: _refreshHistory,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        _Composer(
          controller: _controller,
          isListening: _isListening,
          micEnabled: _stt.isAvailable,
          replyPending: widget.petProvider.replyPending,
          onSend: _send,
          onToggleMic: _toggleMic,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  int _itemCount() {
    final int entries = widget.petProvider.chatEntries.length;
    final int extras = widget.petProvider.replyPending ? 1 : 0;
    final int dateChips = _dateChipCount();
    return entries + extras + dateChips;
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
        final bool showMeta = isFirst ||
            (prev!.isPet != curr.isPet) ||
            (prev.author != curr.author) ||
            _isNewDay(prev.createdAt, curr.createdAt);
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
    if (replyPending) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _TypingAvatar(mood: pet.mood, breath: _breath),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ExpandedChatHeader extends StatelessWidget {
  const _ExpandedChatHeader({
    required this.pet,
    required this.serverOnline,
    required this.ttsEnabled,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onCollapse,
  });

  final Pet pet;
  final bool serverOnline;
  final bool ttsEnabled;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            MochiPetAvatar(mood: pet.mood, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Chat with Mochi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${pet.mood.label} tone \u00b7 short warm replies',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _StatusDots(
              serverOnline: serverOnline,
              ttsEnabled: ttsEnabled,
            ),
            if (onToggleFullscreen != null) ...<Widget>[
              const SizedBox(width: 6),
              _IconAction(
                icon: isFullscreen
                    ? Icons.close_fullscreen_rounded
                    : Icons.open_in_full_rounded,
                tooltip: isFullscreen ? 'Exit full' : 'Full screen',
                onPressed: onToggleFullscreen!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _DragHandle(
          icon: Icons.keyboard_arrow_up_rounded,
          onTap: onCollapse,
        ),
      ],
    );
  }
}

class _CollapsedChatHeader extends StatelessWidget {
  const _CollapsedChatHeader({
    required this.pet,
    required this.serverOnline,
    required this.ttsEnabled,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onExpand,
  });

  final Pet pet;
  final bool serverOnline;
  final bool ttsEnabled;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            MochiPetAvatar(mood: pet.mood, size: 32),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Chat with Mochi',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${pet.mood.label} tone ready',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _StatusDots(
              serverOnline: serverOnline,
              ttsEnabled: ttsEnabled,
            ),
            if (onToggleFullscreen != null) ...<Widget>[
              const SizedBox(width: 6),
              _IconAction(
                icon: isFullscreen
                    ? Icons.close_fullscreen_rounded
                    : Icons.open_in_full_rounded,
                tooltip: isFullscreen ? 'Exit full' : 'Full screen',
                onPressed: onToggleFullscreen!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        _DragHandle(
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: onExpand,
        ),
      ],
    );
  }
}

class _StatusDots extends StatelessWidget {
  const _StatusDots({required this.serverOnline, required this.ttsEnabled});

  final bool serverOnline;
  final bool ttsEnabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StatusDot(
          color: serverOnline ? MochiPalette.mint : MochiPalette.peach,
          tooltip: serverOnline ? 'Live history' : 'Offline',
          icon: serverOnline
              ? Icons.sync_rounded
              : Icons.sync_problem_rounded,
        ),
        const SizedBox(width: 6),
        _StatusDot(
          color: ttsEnabled ? MochiPalette.lightPink : MochiPalette.cloudBlue,
          tooltip: ttsEnabled ? 'Voice on' : 'Voice muted',
          icon: ttsEnabled
              ? Icons.volume_up_rounded
              : Icons.volume_off_rounded,
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({
    required this.color,
    required this.tooltip,
    required this.icon,
  });

  final Color color;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: MochiPalette.ink, width: 1.5),
        ),
        child: Icon(icon, size: 14, color: MochiPalette.ink),
      ),
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
    return Material(
      color: Colors.white,
      shape: const CircleBorder(
        side: BorderSide(color: MochiPalette.ink, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: MochiPalette.ink),
          ),
        ),
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: MochiPalette.ink.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 2),
            Icon(icon, size: 16, color: MochiPalette.ink.withValues(alpha: 0.6)),
          ],
        ),
      ),
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
  const _TypingAvatar({required this.mood, required this.breath});

  final MochiMood mood;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
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
          child: MochiPetAvatar(mood: mood, size: 32),
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
            '${mood.label.toLowerCase()} \u00b7 thinking',
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
  const _EmptyChatIntro({required this.pet, required this.breath});

  final Pet pet;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    final List<Color> swatch = <Color>[
      MochiPalette.lightPink,
      MochiPalette.cloudBlue,
      MochiPalette.yellow,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List<Widget>.generate(swatch.length, (int i) {
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: i == 1 ? 8 : 0),
                child: AnimatedBuilder(
                  animation: breath,
                  builder: (BuildContext context, Widget? child) {
                    final double phase = (breath.value + i / swatch.length) % 1.0;
                    final double opacity = 0.55 + (0.45 * phase);
                    return Opacity(opacity: opacity, child: child);
                  },
                  child: Container(
                    width: 22,
                    height: 12,
                    decoration: BoxDecoration(
                      color: swatch[i],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: MochiPalette.ink,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          MochiPetAvatar(mood: pet.mood, size: 72),
          const SizedBox(height: 14),
          Text(
            'Mochi is listening',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Send a tiny moment to begin the shared chat history.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh if messages were added elsewhere.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 12,
                  color: MochiPalette.ink.withValues(alpha: 0.55),
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
    required this.isListening,
    required this.micEnabled,
    required this.replyPending,
    required this.onSend,
    required this.onToggleMic,
  });

  final TextEditingController controller;
  final bool isListening;
  final bool micEnabled;
  final bool replyPending;
  final Future<void> Function({String inputType}) onSend;
  final VoidCallback onToggleMic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: pixelCardDecoration(MochiPalette.yellow),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: isListening
                        ? 'Listening...'
                        : 'Tell Mochi a tiny moment...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: micEnabled ? onToggleMic : null,
                icon: Icon(
                  isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                ),
                color: isListening ? MochiPalette.lightPink : null,
                tooltip: 'Voice input',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: replyPending ? null : onSend,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          if (isListening) ...<Widget>[
            const SizedBox(height: 8),
            _ListeningPill(),
          ],
        ],
      ),
    );
  }
}

class _ListeningPill extends StatefulWidget {
  @override
  State<_ListeningPill> createState() => _ListeningPillState();
}

class _ListeningPillState extends State<_ListeningPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: MochiPalette.lightPink,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: MochiPalette.ink, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedBuilder(
              animation: _controller,
              builder: (BuildContext context, Widget? child) {
                final double scale = 0.7 + (_controller.value * 0.5);
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: MochiPalette.ink,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Listening \u00b7 tap mic to stop',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 11,
                    color: MochiPalette.ink,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
