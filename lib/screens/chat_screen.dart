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
  });

  final PetProvider petProvider;
  final MemberProvider memberProvider;
  final Future<void> Function(String text) onSendMessage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.petProvider.chatEntries.length !=
            widget.petProvider.chatEntries.length ||
        oldWidget.petProvider.replyPending != widget.petProvider.replyPending) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
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

  Future<void> _send() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || widget.petProvider.replyPending) {
      return;
    }
    _controller.clear();
    await widget.onSendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final Member currentMember = widget.memberProvider.currentMember;
    final pet = widget.petProvider.pet;

    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: pixelCardDecoration(pet.mood.tint),
          child: Row(
            children: <Widget>[
              MemberAvatar(
                member: Member(
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
              _ChatBadge(
                label: widget.petProvider.ttsEnabled
                    ? 'Voice on'
                    : 'Voice muted',
                color: widget.petProvider.ttsEnabled
                    ? MochiPalette.lightPink
                    : MochiPalette.cloudBlue,
                icon: widget.petProvider.ttsEnabled
                    ? Icons.volume_up_rounded
                    : Icons.volume_off_rounded,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: pixelCardDecoration(MochiPalette.cloudBlue),
            child: ListView.separated(
              controller: _scrollController,
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
        const SizedBox(height: 12),
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
