import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/utils/format.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/order.dart';

/// Builds a half-page (A5) receipt with the customer's name and opens the
/// system print / save-as-PDF / share dialog. Cairo covers Arabic and Latin text;
/// the font is fetched once from Google Fonts and cached by the printing package.
Future<void> showReceipt(
  BuildContext context, {
  required Order order,
  required OrderContact contact,
  required AppSettings settings,
  required String lang,
  required Map<String, String> labels,
}) async {
  final regular = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final rtl = lang == 'ar';
  final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  final muted = PdfColor.fromHex('#6B5755');
  final brand = PdfColor.fromHex('#DC0A22');

  pw.Widget row(String a, String b, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(a, style: pw.TextStyle(fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(b, style: pw.TextStyle(fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  final doc = pw.Document(
    title: '${settings.restaurantName} #${order.code}',
    author: settings.restaurantName,
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: const pw.EdgeInsets.all(28),
      textDirection: dir,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Text(settings.restaurantName,
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: brand)),
          if (settings.contactPhone.isNotEmpty)
            pw.Text(settings.contactPhone, style: pw.TextStyle(fontSize: 10, color: muted), textDirection: pw.TextDirection.ltr),
          pw.SizedBox(height: 12),
          pw.Text('${labels['receipt']}  #${order.code}',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(DateFormat('dd/MM/yyyy HH:mm').format((order.createdAt ?? DateTime.now()).toLocal()),
              style: pw.TextStyle(fontSize: 10, color: muted), textDirection: pw.TextDirection.ltr),
          pw.SizedBox(height: 10),
          pw.Text('${labels['customer']}: ${contact.name}', style: const pw.TextStyle(fontSize: 11)),
          pw.Text('${contact.phone}', style: const pw.TextStyle(fontSize: 11), textDirection: pw.TextDirection.ltr),
          pw.Text('${order.area} · ${contact.address}', style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 10),
          pw.Divider(color: PdfColors.grey400),
          for (final line in order.lines)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('${Fmt.number(line.qty, lang)} × ${line.name.of(lang)}',
                            style: const pw.TextStyle(fontSize: 11)),
                        if (line.options.isNotEmpty)
                          pw.Text(line.options.map((o) => o.of(lang)).join(' · '),
                              style: pw.TextStyle(fontSize: 9, color: muted)),
                      ],
                    ),
                  ),
                  pw.Text(Fmt.money(line.lineTotal, lang), style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
          pw.Divider(color: PdfColors.grey400),
          row(labels['subtotal']!, Fmt.money(order.subtotal, lang)),
          row(labels['delivery']!, Fmt.money(order.deliveryFee, lang)),
          row(labels['total']!, Fmt.money(order.total, lang), strong: true),
          pw.SizedBox(height: 8),
          pw.Text(labels['payment']!, style: pw.TextStyle(fontSize: 10, color: muted)),
          pw.Spacer(),
          pw.Center(child: pw.Text(labels['thanks']!, style: pw.TextStyle(fontSize: 12, color: brand))),
        ],
      ),
    ),
  );

  final safeName = contact.name.trim().replaceAll(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true), '_');
  await Printing.layoutPdf(
    name: 'Receipt-${order.code}-$safeName.pdf',
    format: PdfPageFormat.a5,
    onLayout: (_) => doc.save(),
  );
}
