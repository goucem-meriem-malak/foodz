import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/language_menu.dart';
import '../../core/widgets/skeleton.dart';
import '../../core/widgets/state_view.dart';

/// Reads assets/legal/<doc>_<lang>.md and shows it as simple readable text.
/// Supported markup: "# " and "## " headings, "- " bullets, blank-line paragraphs.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc;

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  Future<String>? _text;
  String? _lang;

  String get _kind => widget.doc == 'privacy' ? 'privacy' : 'terms';

  void _load(String lang) {
    _lang = lang;
    _text = rootBundle.loadString('assets/legal/${_kind}_$lang.md');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    if (_lang != lang) _load(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(_kind == 'privacy' ? l.privacyPolicy : l.termsOfUse),
        actions: const [LanguageMenu()],
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _text,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(Space.s24),
                child: Column(
                  children: [
                    Skeleton(height: 28, width: 220),
                    SizedBox(height: Space.s16),
                    Skeleton(height: 16),
                    SizedBox(height: Space.s8),
                    Skeleton(height: 16),
                    SizedBox(height: Space.s8),
                    Skeleton(height: 16, width: 260),
                  ],
                ),
              );
            }
            if (snap.hasError || snap.data == null) {
              return StateView(
                icon: Icons.error_outline_rounded,
                isError: true,
                title: l.somethingWrongTitle,
                message: l.errGeneric,
              );
            }
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.all(Space.s24),
                  children: [
                    Text(l.legalDraftNote, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: Space.s16),
                    ..._blocks(context, snap.data!),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _blocks(BuildContext context, String source) {
    final text = Theme.of(context).textTheme;
    final widgets = <Widget>[];
    for (final raw in source.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: Space.s24, bottom: Space.s8),
          child: Text(line.substring(3), style: text.titleMedium),
        ));
      } else if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.s8),
          child: Text(line.substring(2), style: text.headlineSmall),
        ));
      } else if (line.startsWith('- ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.s8, left: Space.s8, right: Space.s8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(line.substring(2), style: text.bodyMedium)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: Space.s12),
          child: Text(line, style: text.bodyMedium),
        ));
      }
    }
    return widgets;
  }
}
