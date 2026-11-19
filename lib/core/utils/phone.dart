import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/l10n.dart';

/// Opens the phone dialer. Where that is not possible (web, desktop) the
/// number is copied instead, so the caller can still dial it.
Future<void> callPhone(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  final copiedText = context.l10n.numberCopied;
  var opened = false;
  try {
    opened = await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    await Clipboard.setData(ClipboardData(text: phone));
    messenger.showSnackBar(SnackBar(content: Text(copiedText)));
  }
}
