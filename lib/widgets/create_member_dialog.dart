import 'package:flutter/material.dart';

import '../config/app_config.dart';

class MemberDraft {
  const MemberDraft({
    required this.name,
    required this.username,
    required this.color,
  });

  final String name;
  final String username;
  final Color color;
}

class CreateMemberDialog extends StatefulWidget {
  const CreateMemberDialog({super.key});

  @override
  State<CreateMemberDialog> createState() => _CreateMemberDialogState();
}

class _CreateMemberDialogState extends State<CreateMemberDialog> {
  late final TextEditingController _nameController = TextEditingController();
  late final TextEditingController _usernameController = TextEditingController();

  final List<Color> _colors = <Color>[
    MochiPalette.sky,
    const Color(0xFFFFAFCB),
    const Color(0xFFFFD466),
    const Color(0xFFA9E6BE),
    MochiPalette.lavender,
    const Color(0xFF7EB8F3),
  ];

  int _selectedColorIndex = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameController.text.trim();
    final String username = _usernameController.text.trim();
    if (name.isEmpty || username.isEmpty) {
      return;
    }

    Navigator.of(
      context,
    ).pop(
      MemberDraft(
        name: name,
        username: username,
        color: _colors[_selectedColorIndex],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add family member'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Mom, Dad, Lea...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'lea, dad.01, alex',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Avatar color',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List<Widget>.generate(_colors.length, (int index) {
                final bool selected = index == _selectedColorIndex;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedColorIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _colors[index],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: MochiPalette.ink,
                        width: selected ? 3 : 2,
                      ),
                      boxShadow: selected
                          ? const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x3328324E),
                                blurRadius: 0,
                                offset: Offset(2, 2),
                              ),
                            ]
                          : null,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
