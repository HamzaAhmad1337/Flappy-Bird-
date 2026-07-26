import 'package:flutter/material.dart';

import '../game/flappy_game.dart';
import '../services/sfx.dart';
import '../services/storage.dart';
import 'ui_kit.dart';

/// Settings: toggle sound, haptics and reduced-motion. Choices persist
/// immediately via Storage.
class Settings extends StatefulWidget {
  const Settings({super.key, required this.game});
  final FlappyGame game;

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  void _close() {
    Sfx.button();
    widget.game.overlays.remove('settings');
  }

  @override
  Widget build(BuildContext context) {
    return ModalScrim(
      onDismiss: _close,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassPanel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text('SETTINGS', style: UiKit.title(26)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _close,
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _Toggle(
                label: 'Sound',
                icon: Icons.volume_up_rounded,
                value: Storage.soundOn,
                onChanged: (v) {
                  Storage.setSoundOn(v);
                  setState(() {});
                  if (v) Sfx.button();
                },
              ),
              _Toggle(
                label: 'Haptics',
                icon: Icons.vibration_rounded,
                value: Storage.hapticsOn,
                onChanged: (v) {
                  Storage.setHapticsOn(v);
                  setState(() {});
                  Sfx.button();
                },
              ),
              _Toggle(
                label: 'Reduced motion',
                icon: Icons.motion_photos_off_rounded,
                value: Storage.reducedMotion,
                onChanged: (v) {
                  Storage.setReducedMotion(v);
                  setState(() {});
                  Sfx.button();
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Flappy Rain • made with Flutter & Flame',
                style: UiKit.label(12, color: Colors.white.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Text(label, style: UiKit.label(17)),
          const Spacer(),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF3A2E00),
            activeTrackColor: UiKit.accent,
          ),
        ],
      ),
    );
  }
}
