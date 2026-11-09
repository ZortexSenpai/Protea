import 'package:flutter_test/flutter_test.dart';

import 'package:protea/src/emoji_shortcodes.dart';

void main() {
  test('isSingleEmoji matches exactly one emoji grapheme', () {
    const single = [
      '😄', // plain emoji
      '👍', // thumbs up
      '👍🏽', // skin tone modifier
      '❤️', // heart with variation selector
      '❤', // bare heart without variation selector
      '☺️', // legacy text symbol promoted to emoji
      '🤦‍♀️', // ZWJ sequence with variation selector
      '👨‍👩‍👧‍👦', // long ZWJ sequence (family)
      '🏳️‍🌈', // flag ZWJ sequence
      '🫱🏼‍🫲🏾', // ZWJ sequence with two skin tones
      '🇩🇪', // regional indicator flag
      '1️⃣', // keycap
      ' 😄 ', // surrounding whitespace is ignored
    ];
    for (final text in single) {
      expect(isSingleEmoji(text), isTrue, reason: 'should match: "$text"');
    }
  });

  test('isSingleEmoji rejects everything else', () {
    const other = [
      '', // empty
      ' ', // whitespace only
      '5', // digits carry the Emoji property but are not emoji
      '#', // so do # and *
      'a', // plain text
      'text', // plain text
      'hi 😄', // text and emoji
      '😄!', // emoji and text
      '😄😄', // two emoji
      '😄 😄', // two emoji with space
      ':)', // ascii smiley
      '12:30', // time, not a shortcode
    ];
    for (final text in other) {
      expect(isSingleEmoji(text), isFalse, reason: 'should not match: "$text"');
    }
  });

  test('replaceEmojiShortcodes replaces known and keeps unknown', () {
    expect(replaceEmojiShortcodes('hi :eyes:'), 'hi 👀');
    expect(
      replaceEmojiShortcodes(':not_a_real_shortcode:'),
      ':not_a_real_shortcode:',
    );
    expect(replaceEmojiShortcodes('meet at 12:30:45'), 'meet at 12:30:45');
  });
}
