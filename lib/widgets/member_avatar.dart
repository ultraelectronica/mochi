import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/member.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    required this.size,
    this.child,
  });

  final Member member;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: member.color,
        shape: BoxShape.circle,
        border: Border.all(color: MochiPalette.ink, width: 2.5),
      ),
      child:
          child ??
          Text(member.initials, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
