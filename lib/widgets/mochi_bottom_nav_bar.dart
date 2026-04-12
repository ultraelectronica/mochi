import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/app_config.dart';

class MochiBottomNavBar extends StatelessWidget {
  const MochiBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const double baseHeight = 118;

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static double overlayPadding(BuildContext context) {
    return baseHeight + MediaQuery.paddingOf(context).bottom;
  }

  static const List<_NavItemData> _items = <_NavItemData>[
    _NavItemData(
      label: 'Chat',
      assetPath: 'assets/icons/svg/chat_svg.svg',
      accent: MochiPalette.lightPink,
    ),
    _NavItemData(
      label: 'Home',
      assetPath: 'assets/icons/svg/home_svg.svg',
      accent: MochiPalette.cloudBlue,
    ),
    _NavItemData(
      label: 'Settings',
      assetPath: 'assets/icons/svg/settings_svg.svg',
      accent: MochiPalette.yellow,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.paddingOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border(
          top: const BorderSide(color: MochiPalette.ink, width: 3),
          left: const BorderSide(color: MochiPalette.ink, width: 3),
          right: const BorderSide(color: MochiPalette.ink, width: 3),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: MochiPalette.cloudBlue.withValues(alpha: 0.45),
            offset: const Offset(0, -6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const <Widget>[
                    _TopPixel(color: MochiPalette.lightPink),
                    SizedBox(width: 8),
                    _TopPixel(color: MochiPalette.cloudBlue),
                    SizedBox(width: 8),
                    _TopPixel(color: MochiPalette.yellow),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: List<Widget>.generate(_items.length, (int index) {
                    final _NavItemData item = _items[index];
                    return Expanded(
                      child: _NavButton(
                        item: item,
                        selected: selectedIndex == index,
                        onTap: () => onSelected(index),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.assetPath,
    required this.accent,
  });

  final String label;
  final String assetPath;
  final Color accent;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? item.accent.withValues(alpha: 0.38)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? MochiPalette.ink : Colors.transparent,
              width: 2,
            ),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: item.accent.withValues(alpha: 0.85),
                      offset: const Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: selected ? 1 : 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MochiPalette.ink, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: SvgPicture.asset(
                        item.assetPath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                  color: selected
                      ? MochiPalette.ink
                      : MochiPalette.ink.withValues(alpha: 0.55),
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopPixel extends StatelessWidget {
  const _TopPixel({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: MochiPalette.ink, width: 1.5),
      ),
    );
  }
}
