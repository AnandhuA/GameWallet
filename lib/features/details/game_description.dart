import 'package:flutter/material.dart';

/// Keeps long catalog descriptions readable without pushing the gallery away.
class GameDescription extends StatefulWidget {
  final String text;
  const GameDescription({super.key, required this.text});

  @override
  State<GameDescription> createState() => _GameDescriptionState();
}

class _GameDescriptionState extends State<GameDescription> {
  bool expanded = false;

  @override
  void didUpdateWidget(covariant GameDescription oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim().isEmpty
        ? 'No description available.'
        : widget.text;
    final style = DefaultTextStyle.of(context).style.copyWith(height: 1.65);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 3,
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (expanded)
              SelectableText(text, style: style)
            else
              Text(
                text,
                style: style,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            if (overflows)
              TextButton.icon(
                onPressed: () => setState(() => expanded = !expanded),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  minimumSize: const Size(48, 48),
                  alignment: Alignment.centerLeft,
                ),
                icon: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                label: Text(expanded ? 'Show less' : 'Read more'),
              ),
          ],
        );
      },
    );
  }
}
