import 'package:flutter_test/flutter_test.dart';
import 'package:protea/src/widgets/emoji_picker.dart';

void main() {
  test('every grid emoji has search keywords and vice versa', () {
    final grid = allGridEmoji();
    final missing = [
      for (final emoji in grid)
        if ((emojiKeywords[emoji] ?? '').isEmpty) emoji,
    ];
    final orphaned = [
      for (final emoji in emojiKeywords.keys)
        if (!grid.contains(emoji)) emoji,
    ];
    expect(missing, isEmpty, reason: 'grid emoji without keywords');
    expect(orphaned, isEmpty, reason: 'keywords for emoji not in the grid');
  });
}
