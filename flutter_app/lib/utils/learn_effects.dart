import 'package:flutter/services.dart';

class LearnEffects {
  static void playTap() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  static void playMessagePop() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.selectionClick();
  }

  static void playCorrect() {
    SystemSound.play(SystemSoundType.click);
    HapticFeedback.lightImpact();
  }

  static void playWrong() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
  }

  static void playSuccess() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.vibrate();
  }
}
