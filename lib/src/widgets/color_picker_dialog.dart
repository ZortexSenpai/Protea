import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n.dart';

/// Asks for a color, starting at [initial]. Returns null when dismissed.
///
/// Hue, saturation and lightness rather than RGB sliders: a theme color is
/// nearly always "this one, a bit darker" or "the same, less loud", which is
/// one slider in HSL and three in RGB. The hex field takes anything pasted
/// from a palette elsewhere.
Future<Color?> showColorPicker(
  BuildContext context, {
  required Color initial,
  required String title,
}) => showDialog<Color>(
  context: context,
  builder: (context) => _ColorPickerDialog(initial: initial, title: title),
);

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initial, required this.title});

  final Color initial;
  final String title;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late HSLColor _color = HSLColor.fromColor(widget.initial);
  late final _hexController = TextEditingController(text: _hex(widget.initial));

  /// A fully desaturated color has no meaningful hue and a black or white one
  /// no meaningful saturation, but dragging those sliders should still work:
  /// the value is kept here instead of being read back from the color.
  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  Color get _value => _color.toColor();

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _update(HSLColor color) {
    setState(() => _color = color);
    _hexController.text = _hex(color.toColor());
  }

  void _applyHex(String text) {
    var hex = text.trim().replaceFirst('#', '');
    if (hex.length == 3) {
      hex = hex.split('').map((char) => '$char$char').join();
    }
    if (hex.length != 6) return;
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return;
    setState(() => _color = HSLColor.fromColor(Color(0xFF000000 | value)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                color: _value,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
            ),
            const SizedBox(height: 16),
            _ChannelSlider(
              label: context.l10n.hue,
              value: _color.hue,
              max: 360,
              // The full spectrum at this color's saturation and lightness,
              // so the track shows what each position would give.
              gradient: [
                for (var hue = 0; hue <= 360; hue += 30)
                  _color.withHue(hue.toDouble()).toColor(),
              ],
              onChanged: (value) => _update(_color.withHue(value)),
            ),
            _ChannelSlider(
              label: context.l10n.saturation,
              value: _color.saturation,
              max: 1,
              gradient: [
                _color.withSaturation(0).toColor(),
                _color.withSaturation(1).toColor(),
              ],
              onChanged: (value) => _update(_color.withSaturation(value)),
            ),
            _ChannelSlider(
              label: context.l10n.lightness,
              value: _color.lightness,
              max: 1,
              gradient: [
                _color.withLightness(0).toColor(),
                _color.withLightness(0.5).toColor(),
                _color.withLightness(1).toColor(),
              ],
              onChanged: (value) => _update(_color.withLightness(value)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _hexController,
              autocorrect: false,
              enableSuggestions: false,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[0-9a-fA-F#]')),
                LengthLimitingTextInputFormatter(7),
              ],
              decoration: InputDecoration(
                labelText: context.l10n.hexColor,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _applyHex,
              onSubmitted: (_) => Navigator.of(context).pop(_value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_value),
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

/// One labelled slider whose track previews the values it can take.
class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.gradient,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final List<Color> gradient;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 88,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 10,
              // The gradient is the point of the track, so the active part
              // must not paint over it.
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              overlayShape: SliderComponentShape.noOverlay,
              trackShape: _GradientTrackShape(gradient),
            ),
            child: Slider(
              value: value.clamp(0, max),
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _GradientTrackShape extends RoundedRectSliderTrackShape {
  const _GradientTrackShape(this.colors);

  final List<Color> colors;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final rect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    final radius = Radius.circular(rect.height / 2);
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );
  }
}
