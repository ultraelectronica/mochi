import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';
import '../models/mood.dart';
import '../models/pet.dart';
import '../providers/member_provider.dart';
import '../providers/pet_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/member_avatar.dart';

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
  final Future<void> Function(String text) onSendMessage;
  final Future<void> Function() onRefreshHistory;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;
  bool _headerCollapsed = false;
  double _headerDragDelta = 0;
  int _lastRenderedEntryCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
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

  Future<void> _send() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || widget.petProvider.replyPending) {
      return;
    }
    _controller.clear();
    await widget.onSendMessage(text);
  }

  Future<void> _refreshHistory() async {
    await widget.onRefreshHistory();
  }

  @override
  Widget build(BuildContext context) {
    final Member currentMember = widget.memberProvider.currentMember;
    final pet = widget.petProvider.pet;
    final int visibleEntryCount =
        widget.petProvider.chatEntries.length +
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
                18,
                _headerCollapsed ? 12 : 16,
                18,
                12,
              ),
              decoration: pixelCardDecoration(pet.mood.tint),
              child: _headerCollapsed
                  ? _CollapsedChatHeader(
                      pet: pet,
                      serverOnline: widget.petProvider.serverOnline,
                      ttsEnabled: widget.petProvider.ttsEnabled,
                      onRefreshHistory: _refreshHistory,
                      isFullscreen: widget.isFullscreen,
                      onToggleFullscreen: widget.onToggleFullscreen,
                      onExpand: () => _setHeaderCollapsed(false),
                    )
                  : _ExpandedChatHeader(
                      pet: pet,
                      serverOnline: widget.petProvider.serverOnline,
                      ttsEnabled: widget.petProvider.ttsEnabled,
                      onRefreshHistory: _refreshHistory,
                      isFullscreen: widget.isFullscreen,
                      onToggleFullscreen: widget.onToggleFullscreen,
                      onCollapse: () => _setHeaderCollapsed(true),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: pixelCardDecoration(MochiPalette.cloudBlue),
            child: RefreshIndicator(
              onRefresh: _refreshHistory,
              child:
                  widget.petProvider.chatEntries.isEmpty &&
                      !widget.petProvider.replyPending
                  ? ListView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: <Widget>[
                        const SizedBox(height: 80),
                        Text(
                          'Mochi is listening. Send the first tiny family moment to begin the shared chat history.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Pull to refresh if older messages were added from another device.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                      itemCount:
                          widget.petProvider.chatEntries.length +
                          (widget.petProvider.replyPending ? 1 : 0),
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (BuildContext context, int index) {
                        if (widget.petProvider.replyPending &&
                            index == widget.petProvider.chatEntries.length) {
                          return _TypingBubble(color: pet.mood.color);
                        }

                        return ChatBubble(
                          entry: widget.petProvider.chatEntries[index],
                          currentMember: currentMember,
                          petProvider: widget.petProvider,
                        );
                      },
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (widget.petProvider.errorMessage != null) ...<Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: pixelCardDecoration(MochiPalette.peach),
            child: Row(
              children: <Widget>[
                const Icon(Icons.sync_problem_rounded, color: MochiPalette.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.petProvider.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: _refreshHistory,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: pixelCardDecoration(MochiPalette.yellow),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Tell Mochi about a tiny family moment...',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: widget.petProvider.replyPending ? null : _send,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final Member petAvatar = Member(
      id: 0,
      name: 'Mochi',
      color: color,
      affection: 0,
      xp: 0,
      note: '',
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        MemberAvatar(
          member: petAvatar,
          size: 34,
          child: const Icon(
            Icons.pets_rounded,
            size: 18,
            color: MochiPalette.ink,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.18),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(color: MochiPalette.ink, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List<Widget>.generate(3, (int index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: MochiPalette.ink.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ExpandedChatHeader extends StatelessWidget {
  const _ExpandedChatHeader({
    required this.pet,
    required this.serverOnline,
    required this.ttsEnabled,
    required this.onRefreshHistory,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onCollapse,
  });

  final Pet pet;
  final bool serverOnline;
  final bool ttsEnabled;
  final Future<void> Function() onRefreshHistory;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            MemberAvatar(
              member: Member(
                id: 0,
                name: 'Mochi',
                color: pet.mood.color,
                affection: 0,
                xp: 0,
                note: '',
              ),
              size: 44,
              child: const Icon(
                Icons.pets_rounded,
                size: 22,
                color: MochiPalette.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Chat room',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '${pet.stage.label} stage, ${pet.mood.label.toLowerCase()} tone, short warm replies.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _ChatHeaderActions(
              serverOnline: serverOnline,
              ttsEnabled: ttsEnabled,
              onRefreshHistory: onRefreshHistory,
              isFullscreen: isFullscreen,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ChatHeaderHandle(
          label: 'Drag up to minimize chat room',
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
    required this.onRefreshHistory,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onExpand,
  });

  final Pet pet;
  final bool serverOnline;
  final bool ttsEnabled;
  final Future<void> Function() onRefreshHistory;
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
            MemberAvatar(
              member: Member(
                id: 0,
                name: 'Mochi',
                color: pet.mood.color,
                affection: 0,
                xp: 0,
                note: '',
              ),
              size: 36,
              child: const Icon(
                Icons.pets_rounded,
                size: 18,
                color: MochiPalette.ink,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Chat room',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${pet.mood.label} tone ready',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            _ChatHeaderActions(
              serverOnline: serverOnline,
              ttsEnabled: ttsEnabled,
              onRefreshHistory: onRefreshHistory,
              isFullscreen: isFullscreen,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ChatHeaderHandle(
          label: 'Drag down to expand chat room',
          icon: Icons.keyboard_arrow_down_rounded,
          onTap: onExpand,
        ),
      ],
    );
  }
}

class _ChatHeaderActions extends StatelessWidget {
  const _ChatHeaderActions({
    required this.serverOnline,
    required this.ttsEnabled,
    required this.onRefreshHistory,
    required this.isFullscreen,
    required this.onToggleFullscreen,
  });

  final bool serverOnline;
  final bool ttsEnabled;
  final Future<void> Function() onRefreshHistory;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _ChatBadge(
          label: serverOnline ? 'Live history' : 'Offline',
          color: serverOnline ? MochiPalette.mint : MochiPalette.peach,
          icon: serverOnline ? Icons.sync_rounded : Icons.sync_problem_rounded,
        ),
        _ChatBadge(
          label: ttsEnabled ? 'Voice on' : 'Voice muted',
          color: ttsEnabled ? MochiPalette.lightPink : MochiPalette.cloudBlue,
          icon: ttsEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        ),
        _ChatActionButton(
          icon: Icons.refresh_rounded,
          label: 'Refresh',
          onPressed: () {
            unawaited(onRefreshHistory());
          },
        ),
        if (onToggleFullscreen != null)
          _ChatActionButton(
            icon: isFullscreen
                ? Icons.close_fullscreen_rounded
                : Icons.open_in_full_rounded,
            label: isFullscreen ? 'Exit full' : 'Full screen',
            onPressed: onToggleFullscreen!,
          ),
      ],
    );
  }
}

class _ChatHeaderHandle extends StatelessWidget {
  const _ChatHeaderHandle({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: MochiPalette.ink.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ChatBadge extends StatelessWidget {
  const _ChatBadge({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MochiPalette.ink, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: MochiPalette.ink),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

class _ChatActionButton extends StatelessWidget {
  const _ChatActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MochiPalette.ink, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: MochiPalette.ink),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
