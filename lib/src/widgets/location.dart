import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:url_launcher/url_launcher.dart';

import '../event_body.dart';
import '../l10n.dart';

/// Extracts latitude/longitude from free-form [input]: plain "52.5, 13.4"
/// pairs, geo: URIs, OpenStreetMap and Google Maps links.
({double lat, double lon})? parseLocationInput(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;
  ({double lat, double lon})? pair(String? a, String? b) {
    final lat = double.tryParse(a ?? '');
    final lon = double.tryParse(b ?? '');
    if (lat == null || lon == null) return null;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) return null;
    return (lat: lat, lon: lon);
  }

  // geo:52.5,13.4[;u=35]
  final geo = RegExp(
    r'^geo:(-?[\d.]+),(-?[\d.]+)',
    caseSensitive: false,
  ).firstMatch(text);
  if (geo != null) return pair(geo.group(1), geo.group(2));
  // OpenStreetMap: …#map=15/52.5/13.4 or …?mlat=52.5&mlon=13.4
  final osm = RegExp(r'#map=\d+/(-?[\d.]+)/(-?[\d.]+)').firstMatch(text);
  if (osm != null) return pair(osm.group(1), osm.group(2));
  final marker = RegExp(
    r'[?&]mlat=(-?[\d.]+).*[?&]mlon=(-?[\d.]+)',
  ).firstMatch(text);
  if (marker != null) return pair(marker.group(1), marker.group(2));
  // Google Maps: …@52.5,13.4,15z or …?q=52.5,13.4
  final at = RegExp(r'@(-?[\d.]+),(-?[\d.]+)').firstMatch(text);
  if (at != null) return pair(at.group(1), at.group(2));
  final q = RegExp(r'[?&]q=(-?[\d.]+),(-?[\d.]+)').firstMatch(text);
  if (q != null) return pair(q.group(1), q.group(2));
  // Plain "52.5, 13.4"
  final plain = RegExp(r'^(-?[\d.]+)\s*[, ]\s*(-?[\d.]+)$').firstMatch(text);
  if (plain != null) return pair(plain.group(1), plain.group(2));
  return null;
}

/// Formats coordinates for display, 5 decimals (~1 m precision).
String formatCoordinates(double lat, double lon) =>
    '${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}';

Future<void> showShareLocationDialog(BuildContext context, Room room) =>
    showDialog(
      context: context,
      builder: (_) => ShareLocationDialog(room: room),
    );

/// Asks for coordinates (or a pasted map link / geo URI) and sends them as
/// an m.location message. Desktop machines rarely know where they are, so
/// manual input is the primary path.
class ShareLocationDialog extends StatefulWidget {
  const ShareLocationDialog({super.key, required this.room});

  final Room room;

  @override
  State<ShareLocationDialog> createState() => _ShareLocationDialogState();
}

class _ShareLocationDialogState extends State<ShareLocationDialog> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final parsed = parseLocationInput(_controller.text);
    if (parsed == null) return;
    setState(() => _busy = true);
    try {
      await widget.room.sendLocation(
        formatCoordinates(parsed.lat, parsed.lon),
        'geo:${parsed.lat},${parsed.lon}',
      );
      if (mounted) Navigator.of(context).pop();
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
    final parsed = parseLocationInput(_controller.text);
    return AlertDialog(
      title: Text(context.l10n.shareLocation),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.locationInputHint,
                prefixIcon: const Icon(Icons.place_outlined),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _share(),
            ),
            const SizedBox(height: 8),
            Text(
              parsed == null
                  ? context.l10n.locationInputHelp
                  : formatCoordinates(parsed.lat, parsed.lon),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: parsed == null
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: parsed == null || _busy ? null : _share,
          child: Text(context.l10n.send),
        ),
      ],
    );
  }
}

/// An m.location message in the timeline: a pin card with the coordinates
/// that opens the spot on OpenStreetMap.
class LocationBubble extends StatelessWidget {
  const LocationBubble({super.key, required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final geoUri = event.content.tryGet<String>('geo_uri') ?? '';
    final parsed = parseLocationInput(geoUri);
    final label = parsed == null
        ? (event.rawBody.isEmpty ? geoUri : event.rawBody)
        : formatCoordinates(parsed.lat, parsed.lon);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: parsed == null
              ? null
              : () => launchUrl(
                  Uri.parse(
                    'https://www.openstreetmap.org/'
                    '?mlat=${parsed.lat}&mlon=${parsed.lon}'
                    '#map=16/${parsed.lat}/${parsed.lon}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.place_outlined, color: colorScheme.primary),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.location,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(label),
                    if (parsed != null)
                      Text(
                        context.l10n.openMap,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
