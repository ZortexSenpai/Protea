import 'package:flutter/material.dart';

import '../l10n.dart';

/// Opens a dialog with an emoji grid and returns the picked emoji, or null.
Future<String?> showEmojiPicker(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: 360,
        height: 420,
        child: _EmojiGrid(onSelected: (emoji) => Navigator.pop(context, emoji)),
      ),
    ),
  );
}

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _smileysEmoji =
      '😀😃😄😁😆😅😂🤣🙂😉😊😇🥰😍🤩😘😋😛😜🤪😝🤗🤭🤫🤔🤨'
      '😐😑😶😏😒🙄😬😌😔😪🤤😴😷🤒🤕🤢🤮🥵🥶🥴😵🤯🤠🥳😎🤓🧐'
      '😕🙁😮😯😲😳🥺😦😨😰😥😢😭😱😖😣😞😓😩😫🥱😤😡😠🤬'
      '😈💀💩🤡👻👽🤖';
  static const _gesturesEmoji =
      '👍👎👌🤌✌️🤞🤟🤘🤙👈👉👆👇☝️✋🤚🖐️🖖👋🤝👏🙌👐🤲🙏💪✊👊🤛🤜';
  static const _heartsSymbolsEmoji =
      '❤️🧡💛💚💙💜🖤🤍🤎💔❣️💕💞💓💗💖💘💝💯💢💥💫💦💨'
      '🎉🎊✨⭐🌟🔥⚡☀️🌈✅❌❓❗';
  static const _animalsNatureEmoji =
      '🐶🐱🐭🐹🐰🦊🐻🐼🐨🐯🦁🐮🐷🐸🐵🐔🐧🐦🦆🦅🦉🐺🐴🦄🐝🐛🦋'
      '🐌🐞🐢🐍🦖🐙🦀🐠🐬🐳🌸🌹🌻🌲🍀🌍';
  static const _foodDrinkEmoji =
      '🍏🍎🍐🍊🍋🍌🍉🍇🍓🫐🍒🍑🥭🍍🥥🥝🍅🥑🥦🥕🌽🍞🧀🍗🍔🍟🍕'
      '🌭🌮🍣🍜🍦🍩🍪🎂🍫🍿☕🍵🍺🍷🥂';
  static const _activitiesObjectsEmoji =
      '⚽🏀🏈⚾🎾🏐🎱🏓🎮🎲🎯🎸🎹🎺🎻🥁🎤🎧🎬🏆🥇🚗🚲✈️🚀'
      '⌚📱💻🖥️📷🔋💡🔑🔨🧲💰💎📌✏️📚✉️📅🔒🎁';

  static List<(String, String)> _categories(BuildContext context) => [
    (context.l10n.smileys, _smileysEmoji),
    (context.l10n.gestures, _gesturesEmoji),
    (context.l10n.heartsAndSymbols, _heartsSymbolsEmoji),
    (context.l10n.animalsAndNature, _animalsNatureEmoji),
    (context.l10n.foodAndDrink, _foodDrinkEmoji),
    (context.l10n.activitiesAndObjects, _activitiesObjectsEmoji),
  ];

  /// Splits a category string into individual emoji, keeping multi-code-unit
  /// glyphs (surrogate pairs, variation selectors) together.
  static List<String> _split(String emojis) {
    final result = <String>[];
    final runes = emojis.runes.toList();
    for (final rune in runes) {
      final char = String.fromCharCode(rune);
      // Variation selector or zero-width joiner: append to previous glyph.
      if ((rune == 0xFE0F || rune == 0x200D) && result.isNotEmpty) {
        result[result.length - 1] += char;
      } else {
        result.add(char);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final (title, emojis) in _categories(context)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(title, style: Theme.of(context).textTheme.labelMedium),
          ),
          Wrap(
            children: [
              for (final emoji in _split(emojis))
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onSelected(emoji),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
