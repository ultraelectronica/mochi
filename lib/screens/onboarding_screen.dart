import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/game_config.dart';
import '../models/member.dart';
import '../services/local_llm/model_manager.dart';
import '../services/world_setup.dart';
import '../widgets/model_setup_panel.dart';

/// First-run flow: name yourself + Mochi, then pick and download the
/// on-device model. Fully local, no accounts.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { profile, model }

class _OnboardingScreenState extends State<OnboardingScreen> {
  _Step _step = _Step.profile;
  bool _busy = false;
  String? _error;

  final TextEditingController _userController = TextEditingController();
  final TextEditingController _petController = TextEditingController(text: 'Mochi');
  final TextEditingController _bioController = TextEditingController();
  DateTime? _birthdate;
  Color _avatarColor = const Color(0xFF1D9E75);

  static const List<Color> _avatarPalette = <Color>[
    Color(0xFF1D9E75),
    Color(0xFF6E7BD9),
    Color(0xFFD9776E),
    Color(0xFF8FC96A),
    Color(0xFFD96E8F),
    Color(0xFF6EC5D9),
  ];

  @override
  void dispose() {
    _userController.dispose();
    _petController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _continueToModel() async {
    if (_busy) {
      return;
    }
    final String userName = _userController.text.trim();
    if (userName.isEmpty) {
      setState(() {
        _error = 'Tell me your name so Mochi knows who is chatting.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await WorldSetup.createWorld(
        userName: userName,
        petName: _petController.text.trim(),
        avatarColor: _avatarColor,
        bio: _bioController.text.trim(),
        birthdate: _birthdate,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _step = _Step.model;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _finish() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onComplete();
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _PixelBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: pixelCardDecoration(
                      _step == _Step.profile
                          ? MochiPalette.cloudBlue
                          : MochiPalette.mint,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Welcome to Mochi',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'One tiny creature, living on this phone. No server, no accounts — just you two.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        if (_step == _Step.profile)
                          _buildProfileStep()
                        else
                          _buildModelStep(),
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: MochiPalette.peach,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'What should I call you?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _userController,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Your name',
            hintText: 'e.g. Sam',
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Name your companion',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _petController,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _continueToModel(),
          decoration: const InputDecoration(
            labelText: 'Mochi\'s name',
            hintText: 'Mochi',
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Pick an avatar color',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _avatarPalette.map((Color color) {
            return GestureDetector(
              onTap: () => setState(() => _avatarColor = color),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _avatarColor == color
                        ? MochiPalette.ink
                        : MochiPalette.ink.withValues(alpha: 0.2),
                    width: _avatarColor == color ? 3 : 1.5,
                  ),
                ),
                child: _avatarColor == color
                    ? const Icon(Icons.check_rounded, color: Colors.white)
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _buildAboutYouSection(),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : _continueToModel,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.arrow_forward_rounded),
          label: const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildAboutYouSection() {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 4),
        leading: const Icon(Icons.auto_awesome_rounded),
        title: Text(
          'Tell Mochi about you',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          'Optional. Mochi remembers what you share — never required.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: <Widget>[
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: GameConfig.maxBioLength,
            decoration: const InputDecoration(
              labelText: 'A little about you',
              hintText: 'e.g. I love rainy days, jazz, and long walks',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickBirthdate,
                  icon: const Icon(Icons.cake_rounded),
                  label: Text(
                    _birthdate == null
                        ? 'Pick your birthday'
                        : 'Birthday: ${formatBirthdate(_birthdate!)}',
                  ),
                ),
              ),
              if (_birthdate != null)
                IconButton(
                  onPressed: () => setState(() => _birthdate = null),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear birthday',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickBirthdate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthdate ?? DateTime(now.year - 15, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthday',
    );
    if (picked != null) {
      setState(() => _birthdate = picked);
    }
  }

  Widget _buildModelStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Download Mochi\'s brain',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'The small model is plenty for cozy one-liners. The big one is smarter if your phone has room.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        ModelSetupPanel(),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: ModelManager.instance,
          builder: (BuildContext context, Widget? child) {
            final bool ready =
                ModelManager.instance.state.model != null &&
                !ModelManager.instance.state.isActive &&
                ModelManager.instance.state.phase == ModelDownloadPhase.done;
            return SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: ready && !_busy ? _finish : null,
                icon: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(ready ? 'Meet Mochi' : 'Download to continue'),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
  }
}

class _PixelBackdrop extends StatelessWidget {
  const _PixelBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _PixelBackdropPainter()));
  }
}

class _PixelBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = MochiPalette.background;
    canvas.drawRect(Offset.zero & size, fill);

    final List<Color> colors = <Color>[
      MochiPalette.cloudBlue.withValues(alpha: 0.42),
      MochiPalette.lightPink.withValues(alpha: 0.36),
      MochiPalette.yellow.withValues(alpha: 0.34),
      MochiPalette.mint.withValues(alpha: 0.32),
    ];

    const double step = 48;
    const double pixel = 8;

    for (double y = 0; y < size.height + step; y += step) {
      for (double x = 0; x < size.width + step; x += step) {
        final int colorIndex =
            (((x / step).round()) + ((y / step).round())) % colors.length;
        final Paint squarePaint = Paint()
          ..isAntiAlias = false
          ..color = colors[colorIndex];
        final double offsetX = x + (colorIndex * 3);
        final double offsetY = y + (((colorIndex + 1) % 3) * 3);
        canvas.drawRect(
          Rect.fromLTWH(offsetX, offsetY, pixel, pixel),
          squarePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
