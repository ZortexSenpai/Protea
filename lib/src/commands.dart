import 'dart:convert';

import 'package:matrix/matrix.dart';

import 'l10n.dart';

/// A slash command shown in the composer's command palette. The SDK
/// registers more (e.g. /sendraw); this list is what we surface to users.
class SlashCommand {
  const SlashCommand(this.name, this.argsHint, this.description);

  final String name;
  final String argsHint;
  final String description;
}

const slashCommands = [
  SlashCommand('me', '<message>', 'Send an emote'),
  SlashCommand('shrug', '[message]', 'Append ¯\\_(ツ)_/¯'),
  SlashCommand('tableflip', '[message]', 'Append (╯°□°)╯︵ ┻━┻'),
  SlashCommand('unflip', '[message]', 'Append ┬─┬ ノ( ゜-゜ノ)'),
  SlashCommand('lenny', '[message]', 'Append ( ͡° ͜ʖ ͡°)'),
  SlashCommand('spoiler', '<message>', 'Hide the message behind a spoiler'),
  SlashCommand('plain', '<message>', 'Send without markdown formatting'),
  SlashCommand('html', '<message>', 'Send raw HTML'),
  SlashCommand('react', '<emoji>', 'React to the message you reply to'),
  SlashCommand('invite', '<@user:server>', 'Invite a user to this room'),
  SlashCommand('kick', '<@user:server>', 'Kick a user from this room'),
  SlashCommand('ban', '<@user:server>', 'Ban a user from this room'),
  SlashCommand('unban', '<@user:server>', 'Unban a user'),
  SlashCommand('op', '<@user:server> [level]', "Set a user's power level"),
  SlashCommand('join', '<#room:server>', 'Join a room'),
  SlashCommand('part', '', 'Leave this room'),
  SlashCommand('leave', '', 'Leave this room'),
  SlashCommand('nick', '<name>', 'Change your display name'),
  SlashCommand('myroomnick', '<name>', 'Change your name in this room only'),
  SlashCommand('topic', '<topic>', 'Set the room topic'),
  SlashCommand('dm', '<@user:server>', 'Open a direct chat'),
  SlashCommand('ignore', '<@user:server>', 'Ignore a user'),
  SlashCommand('unignore', '<@user:server>', 'Stop ignoring a user'),
  SlashCommand('roomupgrade', '<version>', 'Upgrade this room'),
  SlashCommand('discardsession', '', 'Discard the outbound encryption session'),
  SlashCommand('help', '', 'List available commands'),
];

/// Localized description of a palette command; falls back to the English
/// [SlashCommand.description] for unknown names.
String localizedCommandDescription(
  AppLocalizations l10n,
  SlashCommand command,
) => switch (command.name) {
  'me' => l10n.cmdMe,
  'shrug' => l10n.cmdShrug,
  'tableflip' => l10n.cmdTableflip,
  'unflip' => l10n.cmdUnflip,
  'lenny' => l10n.cmdLenny,
  'spoiler' => l10n.cmdSpoiler,
  'plain' => l10n.cmdPlain,
  'html' => l10n.cmdHtml,
  'react' => l10n.cmdReact,
  'invite' => l10n.cmdInvite,
  'kick' => l10n.cmdKick,
  'ban' => l10n.cmdBan,
  'unban' => l10n.cmdUnban,
  'op' => l10n.cmdOp,
  'join' => l10n.cmdJoin,
  'part' || 'leave' => l10n.cmdLeave,
  'nick' => l10n.cmdNick,
  'myroomnick' => l10n.cmdMyRoomNick,
  'topic' => l10n.cmdTopic,
  'dm' => l10n.cmdDm,
  'ignore' => l10n.cmdIgnore,
  'unignore' => l10n.cmdUnignore,
  'roomupgrade' => l10n.cmdRoomUpgrade,
  'discardsession' => l10n.cmdDiscardSession,
  'help' => l10n.cmdHelp,
  _ => command.description,
};

void _addKaomojiCommand(Client client, String name, String kaomoji) {
  client.addCommand(name, (args, stdout) async {
    final room = args.room;
    if (room == null) throw RoomCommandException();
    return room.sendTextEvent(
      args.msg.isEmpty ? kaomoji : '${args.msg} $kaomoji',
      inReplyTo: args.inReplyTo,
      editEventId: args.editEventId,
      parseCommands: false,
      txid: args.txid,
      threadRootEventId: args.threadRootEventId,
      threadLastEventId: args.threadLastEventId,
    );
  });
}

/// Registers Protea's additional slash commands on top of the SDK defaults
/// (/me, /plain, /react, /invite, /kick, /ban, …).
void registerProteaCommands(Client client) {
  _addKaomojiCommand(client, 'shrug', r'¯\_(ツ)_/¯');
  _addKaomojiCommand(client, 'tableflip', '(╯°□°)╯︵ ┻━┻');
  _addKaomojiCommand(client, 'unflip', '┬─┬ ノ( ゜-゜ノ)');
  _addKaomojiCommand(client, 'lenny', '( ͡° ͜ʖ ͡°)');

  client.addCommand('spoiler', (args, stdout) async {
    final room = args.room;
    if (room == null) throw RoomCommandException();
    if (args.msg.isEmpty) {
      throw CommandException('Usage: /spoiler <message>');
    }
    return room.sendEvent({
      'msgtype': MessageTypes.Text,
      'body': '(spoiler) ${args.msg}',
      'format': 'org.matrix.custom.html',
      'formatted_body':
          '<span data-mx-spoiler>${const HtmlEscape().convert(args.msg)}</span>',
    }, txid: args.txid);
  });

  client.addCommand('nick', (args, stdout) async {
    if (args.msg.isEmpty) throw CommandException('Usage: /nick <name>');
    await args.client.setProfileField(args.client.userID!, 'displayname', {
      'displayname': args.msg,
    });
    return null;
  });

  client.addCommand('part', (args, stdout) async {
    final room = args.room;
    if (room == null) throw RoomCommandException();
    await room.leave();
    return null;
  });

  client.addCommand('topic', (args, stdout) async {
    final room = args.room;
    if (room == null) throw RoomCommandException();
    await room.setDescription(args.msg);
    return null;
  });
}
