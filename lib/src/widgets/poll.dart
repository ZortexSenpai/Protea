import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import '../l10n.dart';
import '../nicknames.dart';
import 'mxc_avatar.dart';

/// MSC3381 poll event types (unstable prefixes, as used by Element).
const pollStartType = 'org.matrix.msc3381.poll.start';
const pollResponseType = 'org.matrix.msc3381.poll.response';
const pollEndType = 'org.matrix.msc3381.poll.end';

/// Asks for a question and options, then sends the poll.
/// The poll creation form as an embeddable panel (shown above the
/// composer, not as a popup); [onClose] fires on cancel and after the poll
/// is sent.
class CreatePollPanel extends StatefulWidget {
  const CreatePollPanel({super.key, required this.room, required this.onClose});

  final VoidCallback onClose;

  final Room room;

  @override
  State<CreatePollPanel> createState() => _CreatePollPanelState();
}

class _CreatePollPanelState extends State<CreatePollPanel> {
  final _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((controller) => controller.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pollNeedsQuestionAndOptions)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final seed = DateTime.now().millisecondsSinceEpoch;
      final fallback = StringBuffer(question);
      final answers = <Map<String, Object?>>[];
      for (var i = 0; i < options.length; i++) {
        answers.add({
          'id': 'protea-$seed-$i',
          'org.matrix.msc1767.text': options[i],
        });
        fallback.write('\n${i + 1}. ${options[i]}');
      }
      await widget.room.sendEvent({
        'org.matrix.msc3381.poll.start': {
          'question': {
            'org.matrix.msc1767.text': question,
            'body': question,
            'msgtype': 'm.text',
          },
          'kind': 'org.matrix.msc3381.poll.disclosed',
          'max_selections': 1,
          'answers': answers,
        },
        'org.matrix.msc1767.text': fallback.toString(),
        'body': fallback.toString(),
      }, type: pollStartType);
      if (mounted) widget.onClose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              children: [
                Text(
                  context.l10n.createPoll,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: context.l10n.close,
                  icon: const Icon(Icons.close),
                  onPressed: _busy ? null : widget.onClose,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _questionController,
                    autofocus: true,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: context.l10n.question,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _optionControllers.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: _optionControllers[i],
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: context.l10n.optionNumber(i + 1),
                          border: const OutlineInputBorder(),
                          isDense: true,
                          suffixIcon: _optionControllers.length > 2
                              ? IconButton(
                                  tooltip: context.l10n.removeOption,
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(
                                    () => _optionControllers.removeAt(i),
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  if (_optionControllers.length < 8)
                    TextButton.icon(
                      onPressed: _busy
                          ? null
                          : () => setState(
                              () => _optionControllers.add(
                                TextEditingController(),
                              ),
                            ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.l10n.addOption),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _busy ? null : widget.onClose,
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _busy ? null : _send,
                  child: Text(context.l10n.create),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders a poll: options with live results, tap to vote, ended state.
class PollBubble extends StatelessWidget {
  const PollBubble({super.key, required this.event, required this.timeline});

  final Event event;
  final Timeline timeline;

  Map<String, Object?>? get _poll =>
      event.content.tryGetMap<String, Object?>('org.matrix.msc3381.poll.start');

  Future<void> _vote(BuildContext context, String answerId) async {
    try {
      await event.room.sendEvent({
        'm.relates_to': {
          'rel_type': RelationshipTypes.reference,
          'event_id': event.eventId,
        },
        'org.matrix.msc3381.poll.response': {
          'answers': [answerId],
        },
      }, type: pollResponseType);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final poll = _poll;
    if (poll == null) return Text(event.body);
    final question =
        poll
            .tryGetMap<String, Object?>('question')
            ?.tryGet<String>('org.matrix.msc1767.text') ??
        event.body;
    final answers = poll.tryGetList<Map<String, Object?>>('answers') ?? [];

    // Latest response per user wins; poll.end from the sender closes it.
    final references = event.aggregatedEvents(
      timeline,
      RelationshipTypes.reference,
    );
    final latestBySender = <String, Event>{};
    var ended = false;
    for (final related in references) {
      if (related.type == pollEndType && related.senderId == event.senderId) {
        ended = true;
      }
      if (related.type != pollResponseType) continue;
      final existing = latestBySender[related.senderId];
      if (existing == null ||
          related.originServerTs.isAfter(existing.originServerTs)) {
        latestBySender[related.senderId] = related;
      }
    }
    final counts = <String, int>{};
    final votersByAnswer = <String, List<User>>{};
    String? ownVote;
    final ownUserId = event.room.client.userID;
    for (final entry in latestBySender.entries) {
      final votes = entry.value.content
          .tryGetMap<String, Object?>('org.matrix.msc3381.poll.response')
          ?.tryGetList<String>('answers');
      final answerId = votes?.isNotEmpty == true ? votes!.first : null;
      if (answerId == null) continue;
      counts[answerId] = (counts[answerId] ?? 0) + 1;
      (votersByAnswer[answerId] ??= []).add(
        event.room.unsafeGetUserFromMemoryOrFallback(entry.key),
      );
      if (entry.key == ownUserId) ownVote = answerId;
    }
    final totalVotes = counts.values.fold(0, (sum, count) => sum + count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.poll_outlined, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                question,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final answer in answers)
          Builder(
            builder: (context) {
              final id = answer.tryGet<String>('id') ?? '';
              final text =
                  answer.tryGet<String>('org.matrix.msc1767.text') ?? '';
              final count = counts[id] ?? 0;
              final voters = votersByAnswer[id] ?? const <User>[];
              final fraction = totalVotes > 0 ? count / totalVotes : 0.0;
              final isOwn = ownVote == id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: ended ? null : () => _vote(context, id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isOwn
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 16,
                            color: isOwn ? colorScheme.primary : null,
                          ),
                          const SizedBox(width: 6),
                          Flexible(child: Text(text)),
                          const SizedBox(width: 8),
                          Text(
                            '$count',
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 5,
                            backgroundColor: colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                      ),
                      if (voters.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Tooltip(
                            message: voters
                                .map((user) => user.nickOrDisplayname)
                                .join(', '),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final user in voters.take(5))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 2),
                                    child: MxcAvatar(
                                      client: event.room.client,
                                      name: user.nickOrDisplayname,
                                      avatarUrl: user.avatarUrl,
                                      radius: 8,
                                    ),
                                  ),
                                if (voters.length > 5)
                                  Text(
                                    '+${voters.length - 5}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        Text(
          ended
              ? context.l10n.finalResults(totalVotes)
              : context.l10n.voteCount(totalVotes),
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

/// Ends [pollEvent] (sender only) by sending the MSC3381 end event.
Future<void> endPoll(Event pollEvent) => pollEvent.room.sendEvent({
  'm.relates_to': {
    'rel_type': RelationshipTypes.reference,
    'event_id': pollEvent.eventId,
  },
  'org.matrix.msc3381.poll.end': <String, Object?>{},
  'org.matrix.msc1767.text': 'The poll has ended.',
}, type: pollEndType);
