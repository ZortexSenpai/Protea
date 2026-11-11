/// Text emoji shortcodes (`:eyes:` → 👀), Discord/GitHub naming with the
/// common aliases. Applied to outgoing text and when rendering message
/// bodies, so shortcodes typed here or sent literally by other clients
/// show as the emoji they mean.
library;

final _shortcodePattern = RegExp(r':([a-zA-Z0-9_+\-]+):');

/// URLs (any `scheme://…`, or a bare `www.…`), up to whitespace, a quote
/// or an HTML tag boundary — so both plain-text links and `href="…"`
/// attribute values in formatted bodies are covered. Shortcode-looking
/// path segments like `/a:x:b` belong to the link, not to the emoji
/// syntax, and must survive intact for the link to still open.
final _urlPattern = RegExp(
  r'''(?:[a-zA-Z][a-zA-Z0-9+.\-]*://|www\.)[^\s<>"']+''',
);

/// Replaces every known `:shortcode:` in [text] with its emoji; unknown
/// names, URLs, and things that merely look like shortcodes (e.g. times
/// in `12:30:45`) are left untouched.
String replaceEmojiShortcodes(String text) {
  if (!text.contains(':')) return text;
  return text.splitMapJoin(
    _urlPattern,
    onMatch: (url) => url.group(0)!,
    onNonMatch: (segment) =>
        segment.replaceAllMapped(_shortcodePattern, (match) {
          final emoji = emojiShortcodes[match.group(1)!.toLowerCase()];
          return emoji ?? match.group(0)!;
        }),
  );
}

/// Matches a string that is exactly one emoji grapheme: a flag (two
/// regional indicators), a keycap, or an emoji — with optional variation
/// selector, skin tone and further ZWJ-joined emoji. The `[#*0-9]`
/// lookahead keeps plain digits out (they carry the Emoji property).
final _singleEmojiPattern = RegExp(
  // The analyzer's regex checker doesn't know unicode-mode property
  // escapes (\p{...}); the pattern is valid and covered by tests.
  // ignore: valid_regexps
  r'^(?:'
  r'[\u{1F1E6}-\u{1F1FF}]{2}'
  r'|[#*0-9]\uFE0F?\u20E3'
  r'|(?:\p{Emoji_Presentation}|(?![#*0-9])\p{Emoji}\uFE0F?)'
  r'[\u{1F3FB}-\u{1F3FF}]?'
  r'(?:\u200D(?:\p{Emoji_Presentation}|\p{Emoji})\uFE0F?[\u{1F3FB}-\u{1F3FF}]?)*'
  r')$',
  unicode: true,
);

/// True when [text] (ignoring surrounding whitespace) is exactly one
/// emoji, e.g. "👍", "👍🏽", "🤦‍♀️" or "🇩🇪" — used for jumbo rendering
/// of emoji-only messages.
bool isSingleEmoji(String text) => _singleEmojiPattern.hasMatch(text.trim());

const emojiShortcodes = <String, String>{
  // Smileys
  'grinning': '😀', 'smiley': '😃', 'smile': '😄', 'grin': '😁',
  'laughing': '😆', 'satisfied': '😆', 'sweat_smile': '😅', 'joy': '😂',
  'rofl': '🤣', 'slight_smile': '🙂', 'slightly_smiling_face': '🙂',
  'wink': '😉',
  'blush': '😊',
  'innocent': '😇',
  'smiling_face_with_hearts': '🥰',
  'heart_eyes': '😍', 'star_struck': '🤩', 'kissing_heart': '😘', 'yum': '😋',
  'stuck_out_tongue': '😛', 'stuck_out_tongue_winking_eye': '😜',
  'zany_face': '🤪', 'stuck_out_tongue_closed_eyes': '😝', 'hugs': '🤗',
  'hand_over_mouth': '🤭', 'shushing_face': '🤫', 'thinking': '🤔',
  'raised_eyebrow': '🤨', 'neutral_face': '😐', 'expressionless': '😑',
  'no_mouth': '😶', 'smirk': '😏', 'unamused': '😒', 'roll_eyes': '🙄',
  'grimacing': '😬', 'relieved': '😌', 'pensive': '😔', 'sleepy': '😪',
  'drooling_face': '🤤', 'sleeping': '😴', 'mask': '😷',
  'face_with_thermometer': '🤒', 'face_with_head_bandage': '🤕',
  'nauseated_face': '🤢', 'vomiting_face': '🤮', 'hot_face': '🥵',
  'cold_face': '🥶', 'woozy_face': '🥴', 'dizzy_face': '😵',
  'exploding_head': '🤯', 'cowboy_hat_face': '🤠', 'partying_face': '🥳',
  'sunglasses': '😎', 'nerd_face': '🤓', 'monocle_face': '🧐',
  'confused': '😕', 'slight_frown': '🙁', 'slightly_frowning_face': '🙁',
  'open_mouth': '😮', 'hushed': '😯', 'astonished': '😲', 'flushed': '😳',
  'pleading_face': '🥺', 'frowning': '😦', 'fearful': '😨', 'cold_sweat': '😰',
  'disappointed_relieved': '😥', 'cry': '😢', 'sob': '😭', 'scream': '😱',
  'confounded': '😖', 'persevere': '😣', 'disappointed': '😞',
  'sweat': '😓', 'weary': '😩', 'tired_face': '😫', 'yawning_face': '🥱',
  'triumph': '😤', 'rage': '😡', 'pout': '😡', 'angry': '😠',
  'cursing_face': '🤬', 'smiling_imp': '😈', 'skull': '💀',
  'skull_and_crossbones': '☠️', 'poop': '💩', 'hankey': '💩', 'shit': '💩',
  'clown_face': '🤡', 'ghost': '👻', 'alien': '👽', 'robot': '🤖',
  'upside_down_face': '🙃', 'money_mouth_face': '🤑', 'lying_face': '🤥',
  'zipper_mouth_face': '🤐', 'salute': '🫡', 'melting_face': '🫠',
  // People & gestures
  'eyes': '👀', 'eye': '👁️', 'thumbsup': '👍', '+1': '👍',
  'thumbsdown': '👎', '-1': '👎', 'ok_hand': '👌', 'pinched_fingers': '🤌',
  'v': '✌️', 'crossed_fingers': '🤞', 'love_you_gesture': '🤟',
  'metal': '🤘', 'call_me_hand': '🤙', 'point_left': '👈',
  'point_right': '👉', 'point_up_2': '👆', 'point_down': '👇',
  'point_up': '☝️', 'raised_hand': '✋', 'raised_back_of_hand': '🤚',
  'raised_hand_with_fingers_splayed': '🖐️', 'vulcan_salute': '🖖',
  'wave': '👋', 'handshake': '🤝', 'clap': '👏', 'raised_hands': '🙌',
  'open_hands': '👐', 'palms_up_together': '🤲', 'pray': '🙏',
  'muscle': '💪', 'fist': '✊', 'facepunch': '👊', 'punch': '👊',
  'fist_left': '🤛', 'fist_right': '🤜', 'writing_hand': '✍️',
  'nail_care': '💅', 'shrug': '🤷', 'person_shrugging': '🤷',
  'facepalm': '🤦', 'person_facepalming': '🤦', 'brain': '🧠',
  'tongue': '👅', 'lips': '👄', 'ear': '👂', 'nose': '👃',
  // Hearts & symbols
  'heart': '❤️', 'orange_heart': '🧡', 'yellow_heart': '💛',
  'green_heart': '💚', 'blue_heart': '💙', 'purple_heart': '💜',
  'black_heart': '🖤', 'white_heart': '🤍', 'brown_heart': '🤎',
  'broken_heart': '💔', 'heavy_heart_exclamation': '❣️', 'two_hearts': '💕',
  'revolving_hearts': '💞', 'heartbeat': '💓', 'heartpulse': '💗',
  'sparkling_heart': '💖', 'cupid': '💘', 'gift_heart': '💝', '100': '💯',
  'anger': '💢', 'boom': '💥', 'collision': '💥', 'dizzy': '💫',
  'sweat_drops': '💦', 'dash': '💨', 'tada': '🎉', 'confetti_ball': '🎊',
  'sparkles': '✨', 'star': '⭐', 'star2': '🌟', 'fire': '🔥', 'zap': '⚡',
  'sunny': '☀️', 'rainbow': '🌈', 'white_check_mark': '✅', 'x': '❌',
  'question': '❓', 'exclamation': '❗', 'warning': '⚠️',
  'check': '✔️', 'heavy_check_mark': '✔️', 'zzz': '💤',
  // Animals & nature
  'dog': '🐶', 'cat': '🐱', 'mouse': '🐭', 'hamster': '🐹', 'rabbit': '🐰',
  'fox_face': '🦊', 'bear': '🐻', 'panda_face': '🐼', 'koala': '🐨',
  'tiger': '🐯', 'lion': '🦁', 'cow': '🐮', 'pig': '🐷', 'frog': '🐸',
  'monkey_face': '🐵', 'chicken': '🐔', 'penguin': '🐧', 'bird': '🐦',
  'duck': '🦆', 'eagle': '🦅', 'owl': '🦉', 'wolf': '🐺', 'horse': '🐴',
  'unicorn': '🦄', 'bee': '🐝', 'bug': '🐛', 'butterfly': '🦋',
  'snail': '🐌', 'lady_beetle': '🐞', 'turtle': '🐢', 'snake': '🐍',
  't-rex': '🦖', 'octopus': '🐙', 'crab': '🦀', 'tropical_fish': '🐠',
  'dolphin': '🐬', 'whale': '🐳', 'cherry_blossom': '🌸', 'rose': '🌹',
  'sunflower': '🌻', 'evergreen_tree': '🌲', 'four_leaf_clover': '🍀',
  'earth_africa': '🌍', 'seedling': '🌱', 'crescent_moon': '🌙',
  // Food & drink
  'green_apple': '🍏', 'apple': '🍎', 'pear': '🍐', 'tangerine': '🍊',
  'lemon': '🍋', 'banana': '🍌', 'watermelon': '🍉', 'grapes': '🍇',
  'strawberry': '🍓', 'blueberries': '🫐', 'cherries': '🍒', 'peach': '🍑',
  'mango': '🥭', 'pineapple': '🍍', 'coconut': '🥥', 'kiwi_fruit': '🥝',
  'tomato': '🍅', 'avocado': '🥑', 'broccoli': '🥦', 'carrot': '🥕',
  'corn': '🌽', 'bread': '🍞', 'cheese': '🧀', 'poultry_leg': '🍗',
  'hamburger': '🍔', 'fries': '🍟', 'pizza': '🍕', 'hotdog': '🌭',
  'taco': '🌮', 'sushi': '🍣', 'ramen': '🍜', 'icecream': '🍦',
  'doughnut': '🍩', 'cookie': '🍪', 'birthday': '🎂', 'cake': '🍰',
  'chocolate_bar': '🍫', 'popcorn': '🍿', 'coffee': '☕', 'tea': '🍵',
  'beer': '🍺', 'beers': '🍻', 'wine_glass': '🍷', 'clinking_glasses': '🥂',
  // Activities & objects
  'soccer': '⚽', 'basketball': '🏀', 'football': '🏈', 'baseball': '⚾',
  'tennis': '🎾', 'volleyball': '🏐', '8ball': '🎱', 'ping_pong': '🏓',
  'video_game': '🎮', 'game_die': '🎲', 'dart': '🎯', 'guitar': '🎸',
  'musical_keyboard': '🎹', 'trumpet': '🎺', 'violin': '🎻', 'drum': '🥁',
  'microphone': '🎤', 'headphones': '🎧', 'clapper': '🎬', 'trophy': '🏆',
  'first_place_medal': '🥇', 'car': '🚗', 'bike': '🚲', 'airplane': '✈️',
  'rocket': '🚀', 'watch': '⌚', 'iphone': '📱', 'computer': '💻',
  'desktop_computer': '🖥️', 'camera': '📷', 'battery': '🔋', 'bulb': '💡',
  'key': '🔑', 'hammer': '🔨', 'magnet': '🧲', 'moneybag': '💰',
  'gem': '💎', 'pushpin': '📌', 'pencil2': '✏️', 'books': '📚',
  'email': '✉️', 'envelope': '✉️', 'calendar': '📅', 'lock': '🔒',
  'gift': '🎁', 'bell': '🔔', 'mag': '🔍', 'hourglass': '⌛',
};
