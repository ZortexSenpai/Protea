import 'package:matrix/matrix.dart';

extension EventRawBody on Event {
  /// The body the event actually carries, empty when it has none.
  ///
  /// [Event.body] stands in `Unknown message format of type "…"` for a
  /// missing body, which is a last-resort label for an event that can't be
  /// rendered at all — never something to print as a caption or a file name.
  /// Clients following MSC2530 send a `filename` and leave `body` out
  /// entirely when a picture has no caption, so this case is routine.
  String get rawBody => content.tryGet<String>('body') ?? '';

  /// The name to show for an attachment: its `filename`, or the body for the
  /// pre-MSC2530 shape where the name was sent as the body. Empty when the
  /// event carries neither, so it never reads as a placeholder.
  String get attachmentName => content.tryGet<String>('filename') ?? rawBody;

  /// A label for an attachment that can't be displayed: what the sender
  /// wrote, or its file name when they wrote nothing.
  String get attachmentLabel => rawBody.isEmpty ? attachmentName : rawBody;
}
