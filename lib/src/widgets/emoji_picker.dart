import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../emoji_shortcodes.dart';
import '../l10n.dart';
import '../motion.dart';
import 'mxc_avatar.dart';

/// A custom emote available to the current room (MSC2545): the shortcode
/// token to insert into the composer and the image to preview. The token
/// is resolved to an `<img data-mx-emoticon>` by the SDK's markdown parser
/// when the message is sent.
typedef PickerEmote = ({String token, String shortcode, Uri url});

/// Shows the emoji grid as a small popover anchored to [context]'s widget
/// (the message bubble whose reaction button was pressed) — no modal
/// dialog, no dimmed barrier. Returns the picked emoji, or null when
/// dismissed by Esc or a click elsewhere.
Future<String?> showEmojiPicker(BuildContext context) {
  final overlayBox =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  final anchorBox = context.findRenderObject() as RenderBox?;
  final anchor = anchorBox == null || !anchorBox.attached
      ? (overlayBox.size.center(Offset.zero) & Size.zero)
      : (anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox) &
            anchorBox.size);
  return Navigator.of(context).push(
    RawDialogRoute<String>(
      barrierColor: Colors.transparent,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: Motion.quick,
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, _) => CustomSingleChildLayout(
        delegate: _PopoverLayoutDelegate(anchor),
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: SizedBox(
            width: 360,
            height: 400,
            child: EmojiPickerPanel(
              onSelected: (emoji) => Navigator.pop(context, emoji),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Places the popover above its anchor (below when there is no room),
/// clamped to the overlay with a small screen margin.
class _PopoverLayoutDelegate extends SingleChildLayoutDelegate {
  _PopoverLayoutDelegate(this.anchor);

  final Rect anchor;

  static const _margin = 8.0;
  static const _gap = 4.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(
        Size(
          constraints.maxWidth - 2 * _margin,
          constraints.maxHeight - 2 * _margin,
        ),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    var y = anchor.top - childSize.height - _gap;
    if (y < _margin) y = anchor.bottom + _gap;
    return Offset(
      anchor.left.clamp(_margin, size.width - childSize.width - _margin),
      y.clamp(_margin, size.height - childSize.height - _margin),
    );
  }

  @override
  bool shouldRelayout(covariant _PopoverLayoutDelegate oldDelegate) =>
      oldDelegate.anchor != anchor;
}

/// The emoji grid with a search bar as an embeddable panel; [onSelected]
/// fires on every pick so several emoji can be inserted in a row.
///
/// When [room] is set, the room's custom emotes (MSC2545 image packs from
/// the room state, the user's account data and subscribed emote rooms)
/// show in their own section and in search results.
class EmojiPickerPanel extends StatefulWidget {
  const EmojiPickerPanel({super.key, required this.onSelected, this.room});

  final ValueChanged<String> onSelected;
  final Room? room;

  @override
  State<EmojiPickerPanel> createState() => _EmojiPickerPanelState();
}

class _EmojiPickerPanelState extends State<EmojiPickerPanel> {
  var _query = '';

  late final List<PickerEmote> _emotes = _loadEmotes();

  /// Shortcodes the emote syntax can express; anything else can't be
  /// typed back and is skipped.
  static final _validShortcode = RegExp(r'^[-\w]+$');

  List<PickerEmote> _loadEmotes() {
    final room = widget.room;
    if (room == null) return const [];
    final packs = room.getImagePacksFlat(ImagePackUsage.emoticon);
    final counts = <String, int>{};
    for (final images in packs.values) {
      for (final name in images.keys) {
        counts[name] = (counts[name] ?? 0) + 1;
      }
    }
    final emotes = <PickerEmote>[];
    for (final pack in packs.entries) {
      for (final image in pack.value.entries) {
        final url = Uri.tryParse(image.value);
        if (url == null || !url.isScheme('mxc')) continue;
        if (!_validShortcode.hasMatch(image.key)) continue;
        // A bare :name: that collides with a unicode shortcode (those are
        // replaced before sending) or with an emote in another pack is
        // qualified with its pack slug, which both replacers leave alone.
        final ambiguous =
            (counts[image.key] ?? 0) > 1 ||
            emojiShortcodes.containsKey(image.key.toLowerCase());
        emotes.add((
          token: ambiguous ? ':${pack.key}~${image.key}:' : ':${image.key}:',
          shortcode: image.key,
          url: url,
        ));
      }
    }
    return emotes;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.searchEmoji,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: _query.isEmpty
              ? _EmojiGrid(
                  onSelected: widget.onSelected,
                  emotes: _emotes,
                  client: widget.room?.client,
                )
              : _EmojiSearchResults(
                  query: _query,
                  onSelected: widget.onSelected,
                  emotes: _emotes,
                  client: widget.room?.client,
                ),
        ),
      ],
    );
  }
}

/// One custom emote in the grid: the image at emoji size with the
/// shortcode as tooltip.
class _EmoteTile extends StatelessWidget {
  const _EmoteTile({
    required this.client,
    required this.emote,
    required this.onSelected,
  });

  final Client client;
  final PickerEmote emote;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: ':${emote.shortcode}:',
    child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () => onSelected(emote.token),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: SizedBox(
          width: 26,
          height: 26,
          child: MxcImage(
            client: client,
            uri: emote.url,
            thumbnailWidth: 64,
            thumbnailHeight: 64,
            thumbnailMethod: ThumbnailMethod.scale,
            fit: BoxFit.contain,
            placeholder: (_) => const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

class _EmojiSearchResults extends StatelessWidget {
  const _EmojiSearchResults({
    required this.query,
    required this.onSelected,
    required this.emotes,
    required this.client,
  });

  final String query;
  final ValueChanged<String> onSelected;
  final List<PickerEmote> emotes;
  final Client? client;

  @override
  Widget build(BuildContext context) {
    final client = this.client;
    final results = [
      for (final entry in emojiKeywords.entries)
        if (entry.value.contains(query)) entry.key,
    ];
    final emoteResults = [
      for (final emote in emotes)
        if (emote.shortcode.toLowerCase().contains(query)) emote,
    ];
    if (results.isEmpty && emoteResults.isEmpty) {
      return Center(child: Text(context.l10n.noEmojiFound));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          children: [
            if (client != null)
              for (final emote in emoteResults)
                _EmoteTile(
                  client: client,
                  emote: emote,
                  onSelected: onSelected,
                ),
            for (final emoji in results)
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
    );
  }
}

/// English search keywords for every emoji in the grid (matched as a
/// substring of the query, lowercase).
const emojiKeywords = <String, String>{
  '😀': 'grinning happy smile face',
  '😃': 'smiley happy joy big eyes',
  '😄': 'smile happy laugh joy',
  '😁': 'beaming grin teeth',
  '😆': 'laughing squint haha',
  '😅': 'sweat smile relief nervous laugh',
  '😂': 'joy tears laugh lol funny',
  '🤣': 'rofl rolling floor laughing lol',
  '🙂': 'slight smile fine',
  '😉': 'wink flirt',
  '😊': 'blush smile happy shy',
  '😇': 'halo innocent angel',
  '🥰': 'hearts love adore smiling',
  '😍': 'heart eyes love crush',
  '🤩': 'star struck excited wow',
  '😘': 'kiss blow love',
  '😋': 'yum tasty delicious tongue',
  '😛': 'tongue out playful',
  '😜': 'wink tongue crazy silly',
  '🤪': 'zany wild crazy goofy',
  '😝': 'squint tongue gross',
  '🤗': 'hug embrace open hands',
  '🤭': 'giggle hand over mouth oops',
  '🤫': 'shush quiet secret',
  '🤔': 'thinking hmm consider',
  '🤨': 'raised eyebrow skeptic suspicious',
  '😐': 'neutral meh blank',
  '😑': 'expressionless annoyed',
  '😶': 'no mouth speechless silent',
  '😏': 'smirk sly',
  '😒': 'unamused annoyed meh',
  '🙄': 'eye roll whatever',
  '😬': 'grimace awkward cringe',
  '😌': 'relieved calm content',
  '😔': 'pensive sad thoughtful',
  '😪': 'sleepy tired',
  '🤤': 'drool hungry desire',
  '😴': 'sleeping zzz asleep',
  '😷': 'mask sick ill doctor',
  '🤒': 'thermometer fever sick',
  '🤕': 'bandage hurt injured head',
  '🤢': 'nauseated sick green gross',
  '🤮': 'vomit puke sick throw up',
  '🥵': 'hot heat sweating overheated',
  '🥶': 'cold freezing frozen ice',
  '🥴': 'woozy drunk dizzy tipsy',
  '😵': 'dizzy knocked out crossed eyes',
  '🤯': 'exploding head mind blown shocked',
  '🤠': 'cowboy hat yeehaw',
  '🥳': 'party celebration birthday hat',
  '😎': 'sunglasses cool',
  '🤓': 'nerd glasses geek',
  '🧐': 'monocle inspect curious fancy',
  '😕': 'confused unsure',
  '🙁': 'frown sad slightly',
  '😮': 'open mouth surprised wow o',
  '😯': 'hushed surprised',
  '😲': 'astonished shocked amazed',
  '😳': 'flushed embarrassed blush shocked',
  '🥺': 'pleading puppy eyes begging cute',
  '😦': 'frowning open mouth worried',
  '😨': 'fearful scared afraid',
  '😰': 'anxious sweat nervous scared',
  '😥': 'sad relieved disappointed sweat',
  '😢': 'crying sad tear',
  '😭': 'sobbing loudly crying bawling sad',
  '😱': 'scream fear shocked terrified',
  '😖': 'confounded frustrated scrunched',
  '😣': 'persevere struggling',
  '😞': 'disappointed sad',
  '😓': 'downcast sweat tired defeated',
  '😩': 'weary tired exhausted whine',
  '😫': 'tired distraught exhausted',
  '🥱': 'yawn bored sleepy tired',
  '😤': 'triumph steam huff frustrated proud',
  '😡': 'pouting angry rage red mad',
  '😠': 'angry mad grumpy',
  '🤬': 'cursing swearing angry symbols rage',
  '😈': 'devil smiling horns evil purple',
  '💀': 'skull dead death dying',
  '💩': 'poop pile crap funny',
  '🤡': 'clown circus joke',
  '👻': 'ghost boo halloween spooky',
  '👽': 'alien ufo extraterrestrial',
  '🤖': 'robot bot machine',
  '👍': 'thumbs up like yes approve ok good',
  '👎': 'thumbs down dislike no bad',
  '👌': 'ok okay perfect fingers',
  '🤌': 'pinched fingers italian chef',
  '✌️': 'victory peace fingers two',
  '🤞': 'crossed fingers luck hope',
  '🤟': 'love you gesture rock',
  '🤘': 'horns rock metal',
  '🤙': 'call me shaka hang loose',
  '👈': 'point left backhand',
  '👉': 'point right backhand',
  '👆': 'point up backhand',
  '👇': 'point down backhand',
  '☝️': 'index up point one',
  '✋': 'raised hand stop high five',
  '🤚': 'raised back of hand',
  '🖐️': 'hand fingers splayed five',
  '🖖': 'vulcan spock salute star trek',
  '👋': 'wave hello goodbye hi bye',
  '🤝': 'handshake deal agreement',
  '👏': 'clap applause bravo',
  '🙌': 'raising hands celebration hooray praise',
  '👐': 'open hands',
  '🤲': 'palms up together prayer',
  '🙏': 'folded hands please thanks pray namaste',
  '💪': 'flexed biceps muscle strong gym',
  '✊': 'raised fist power solidarity',
  '👊': 'fist bump punch bro',
  '🤛': 'left fist bump',
  '🤜': 'right fist bump',
  '❤️': 'red heart love',
  '🧡': 'orange heart love',
  '💛': 'yellow heart love',
  '💚': 'green heart love',
  '💙': 'blue heart love',
  '💜': 'purple heart love',
  '🖤': 'black heart love dark',
  '🤍': 'white heart love pure',
  '🤎': 'brown heart love',
  '💔': 'broken heart heartbreak sad',
  '❣️': 'heart exclamation love',
  '💕': 'two hearts love pink',
  '💞': 'revolving hearts love',
  '💓': 'beating heart love pulse',
  '💗': 'growing heart love',
  '💖': 'sparkling heart love glitter',
  '💘': 'heart with arrow cupid love',
  '💝': 'heart with ribbon gift love',
  '💯': 'hundred points perfect score 100',
  '💢': 'anger symbol mad comic',
  '💥': 'collision boom explosion bang',
  '💫': 'dizzy star swirl',
  '💦': 'sweat droplets water splash',
  '💨': 'dash wind fast smoke',
  '🎉': 'party popper celebration confetti tada',
  '🎊': 'confetti ball celebration party',
  '✨': 'sparkles glitter shiny magic stars',
  '⭐': 'star favorite',
  '🌟': 'glowing star shining',
  '🔥': 'fire flame hot lit burn',
  '⚡': 'lightning zap bolt electric thunder',
  '☀️': 'sun sunny bright weather',
  '🌈': 'rainbow pride colorful weather',
  '✅': 'check mark done yes correct green',
  '❌': 'cross mark no wrong x red',
  '❓': 'question mark red',
  '❗': 'exclamation mark warning red',
  '🐶': 'dog puppy pet face',
  '🐱': 'cat kitten pet face',
  '🐭': 'mouse face rodent',
  '🐹': 'hamster pet face',
  '🐰': 'rabbit bunny face',
  '🦊': 'fox face',
  '🐻': 'bear face',
  '🐼': 'panda face',
  '🐨': 'koala face',
  '🐯': 'tiger face',
  '🦁': 'lion face',
  '🐮': 'cow face',
  '🐷': 'pig face',
  '🐸': 'frog face',
  '🐵': 'monkey face',
  '🐔': 'chicken hen',
  '🐧': 'penguin',
  '🐦': 'bird tweet',
  '🦆': 'duck',
  '🦅': 'eagle bird',
  '🦉': 'owl bird night',
  '🐺': 'wolf face',
  '🐴': 'horse face',
  '🦄': 'unicorn face magic',
  '🐝': 'bee honeybee buzz',
  '🐛': 'bug caterpillar insect',
  '🦋': 'butterfly insect',
  '🐌': 'snail slow',
  '🐞': 'lady beetle ladybug insect',
  '🐢': 'turtle slow tortoise',
  '🐍': 'snake serpent',
  '🦖': 'trex dinosaur',
  '🐙': 'octopus sea',
  '🦀': 'crab sea',
  '🐠': 'tropical fish sea',
  '🐬': 'dolphin sea',
  '🐳': 'whale spouting sea',
  '🌸': 'cherry blossom flower spring pink',
  '🌹': 'rose flower romantic',
  '🌻': 'sunflower flower yellow',
  '🌲': 'evergreen tree pine forest',
  '🍀': 'four leaf clover luck shamrock',
  '🌍': 'earth globe world europe africa planet',
  '🍏': 'green apple fruit',
  '🍎': 'red apple fruit',
  '🍐': 'pear fruit',
  '🍊': 'tangerine orange fruit',
  '🍋': 'lemon fruit sour',
  '🍌': 'banana fruit',
  '🍉': 'watermelon fruit',
  '🍇': 'grapes fruit wine',
  '🍓': 'strawberry fruit',
  '🫐': 'blueberries fruit',
  '🍒': 'cherries fruit',
  '🍑': 'peach fruit butt',
  '🥭': 'mango fruit',
  '🍍': 'pineapple fruit',
  '🥥': 'coconut fruit',
  '🥝': 'kiwi fruit',
  '🍅': 'tomato vegetable',
  '🥑': 'avocado guacamole',
  '🥦': 'broccoli vegetable',
  '🥕': 'carrot vegetable',
  '🌽': 'corn cob maize',
  '🍞': 'bread loaf toast',
  '🧀': 'cheese wedge',
  '🍗': 'poultry leg chicken drumstick',
  '🍔': 'hamburger burger fast food',
  '🍟': 'french fries fast food',
  '🍕': 'pizza slice',
  '🌭': 'hot dog sausage',
  '🌮': 'taco mexican',
  '🍣': 'sushi japanese fish',
  '🍜': 'steaming bowl ramen noodles soup',
  '🍦': 'soft ice cream cone dessert',
  '🍩': 'doughnut donut dessert',
  '🍪': 'cookie dessert biscuit',
  '🎂': 'birthday cake celebration dessert',
  '🍫': 'chocolate bar candy sweet',
  '🍿': 'popcorn movie cinema snack',
  '☕': 'hot beverage coffee tea drink',
  '🍵': 'teacup tea green drink',
  '🍺': 'beer mug drink pint',
  '🍷': 'wine glass drink red',
  '🥂': 'clinking glasses cheers champagne toast',
  '⚽': 'soccer football ball sport',
  '🏀': 'basketball ball sport',
  '🏈': 'american football ball sport',
  '⚾': 'baseball ball sport',
  '🎾': 'tennis ball sport',
  '🏐': 'volleyball ball sport',
  '🎱': 'pool 8 ball billiards eight',
  '🏓': 'ping pong table tennis paddle',
  '🎮': 'video game controller gaming',
  '🎲': 'game die dice board',
  '🎯': 'bullseye direct hit dart target',
  '🎸': 'guitar music rock instrument',
  '🎹': 'musical keyboard piano instrument',
  '🎺': 'trumpet music instrument',
  '🎻': 'violin music instrument',
  '🥁': 'drum music instrument',
  '🎤': 'microphone sing karaoke music',
  '🎧': 'headphone music listen audio',
  '🎬': 'clapper board movie film action',
  '🏆': 'trophy winner champion prize',
  '🥇': 'first place gold medal winner',
  '🚗': 'automobile car red vehicle',
  '🚲': 'bicycle bike cycling',
  '✈️': 'airplane flight travel plane',
  '🚀': 'rocket launch space ship',
  '⌚': 'watch time wrist',
  '📱': 'mobile phone smartphone',
  '💻': 'laptop computer notebook',
  '🖥️': 'desktop computer monitor',
  '📷': 'camera photo picture',
  '🔋': 'battery power charge',
  '💡': 'light bulb idea lamp',
  '🔑': 'key lock password',
  '🔨': 'hammer tool build',
  '🧲': 'magnet attraction',
  '💰': 'money bag dollar rich cash',
  '💎': 'gem stone diamond jewel',
  '📌': 'pushpin pin location',
  '✏️': 'pencil write edit',
  '📚': 'books reading library study',
  '✉️': 'envelope mail letter email',
  '📅': 'calendar date schedule',
  '🔒': 'locked lock secure private',
  '🎁': 'wrapped gift present birthday',
};

/// Every emoji shown in the grid, in display order. Visible for tests: the
/// search keywords must cover all of them.
List<String> allGridEmoji() => [
  for (final emojis in [
    _EmojiGrid._smileysEmoji,
    _EmojiGrid._gesturesEmoji,
    _EmojiGrid._heartsSymbolsEmoji,
    _EmojiGrid._animalsNatureEmoji,
    _EmojiGrid._foodDrinkEmoji,
    _EmojiGrid._activitiesObjectsEmoji,
  ])
    ..._EmojiGrid._split(emojis),
];

class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({
    required this.onSelected,
    this.emotes = const [],
    this.client,
  });

  final ValueChanged<String> onSelected;
  final List<PickerEmote> emotes;
  final Client? client;

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
    final client = this.client;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (client != null && emotes.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              context.l10n.emotes,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Wrap(
            children: [
              for (final emote in emotes)
                _EmoteTile(
                  client: client,
                  emote: emote,
                  onSelected: onSelected,
                ),
            ],
          ),
        ],
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
