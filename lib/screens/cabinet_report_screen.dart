// شاشة طباعة تقرير الكابينة - بتديك خيار ترتيب البيانات حسب الرئيسيات
// أو حسب البوكسات، وبتفتح معاينة/طباعة PDF ممكن تحفظها كنسخة أو تطبعها فعليًا

import 'package:flutter/material.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/box_model.dart';
import '../models/cabinet_model.dart';
import '../models/main_pair_model.dart';
import '../models/terminal_model.dart';
import '../services/firestore_service.dart';

enum ReportOrder { byMainPairs, byBoxes }

class CabinetReportScreen extends StatefulWidget {
  final CabinetModel cabinet;

  const CabinetReportScreen({super.key, required this.cabinet});

  @override
  State<CabinetReportScreen> createState() => _CabinetReportScreenState();
}

class _CabinetReportScreenState extends State<CabinetReportScreen> {
  final _firestoreService = FirestoreService();
  ReportOrder _order = ReportOrder.byMainPairs;
  bool _isGenerating = false;

  Future<void> _generateAndShowPdf() async {
    setState(() => _isGenerating = true);
    try {
      // خط عربي عشان الـ PDF يعرض النص العربي صح (بيتحمل مرة واحدة وبيتخزن كاش)
      final arabicFont = await PdfGoogleFonts.notoNaskhArabicRegular();
      final arabicBold = await PdfGoogleFonts.notoNaskhArabicBold();

      final mainPairs =
          await _firestoreService.streamMainPairs(widget.cabinet.id).first;
      final boxes = await _firestoreService
          .streamBoxesForCabinet(widget.cabinet.id)
          .first;

      final Map<String, List<TerminalModel>> terminalsByBox = {};
      if (_order == ReportOrder.byBoxes) {
        for (final box in boxes) {
          terminalsByBox[box.id] =
              await _firestoreService.streamTerminals(box.id).first;
        }
      }

      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          theme: pw.ThemeData.withFont(base: arabicFont, bold: arabicBold),
          textDirection: pw.TextDirection.rtl,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Text(
                'تقرير كابينة: ${widget.cabinet.name} (${widget.cabinet.code})',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Text('النوع: ${widget.cabinet.type.labelAr}'),
            pw.SizedBox(height: 12),
            if (_order == ReportOrder.byMainPairs)
              ..._buildMainPairsSection(mainPairs)
            else
              ..._buildBoxesSection(boxes, terminalsByBox),
          ],
        ),
      );

      if (mounted) {
        await Printing.layoutPdf(onLayout: (format) async => doc.save());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ أثناء إنشاء التقرير: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<pw.Widget> _buildMainPairsSection(List<MainPairModel> pairs) {
    return [
      pw.Text(
        'الرئيسيات (${pairs.length})',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['الرقم', 'المكان', 'الحالة', 'رقم الهاتف', 'الوجهة'],
        data: pairs
            .map((p) => [
                  p.pairNumber.toString(),
                  p.locationLabel,
                  p.isFaulty
                      ? 'معطل'
                      : (p.phoneNumber != null ? 'مشغول' : 'فاضي'),
                  p.phoneNumber ?? '-',
                  p.destinationType?.labelAr ?? '-',
                ])
            .toList(),
      ),
    ];
  }

  List<pw.Widget> _buildBoxesSection(
    List<BoxModel> boxes,
    Map<String, List<TerminalModel>> terminalsByBox,
  ) {
    final widgets = <pw.Widget>[];
    for (final box in boxes) {
      widgets.add(pw.SizedBox(height: 10));
      widgets.add(pw.Text(
        '${box.name} (سلوت ${box.slotNumber ?? '-'})',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ));
      final terms = terminalsByBox[box.id] ?? [];
      widgets.add(pw.TableHelper.fromTextArray(
        headers: ['الترمنال', 'الرقم', 'العميل', 'النوع', 'العزل', 'معطل'],
        data: terms
            .map((t) => [
                  t.terminalNumber.toString(),
                  t.phoneNumber ?? '-',
                  t.customerName ?? '-',
                  t.customerType?.labelAr ?? '-',
                  t.isolationStatus.labelAr,
                  t.isFaulty ? 'نعم' : 'لا',
                ])
            .toList(),
      ));
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طباعة تقرير الكابينة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اختار ترتيب البيانات في التقرير',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            RadioListTile<ReportOrder>(
              title: const Text('حسب الرئيسيات'),
              value: ReportOrder.byMainPairs,
              groupValue: _order,
              onChanged: (v) => setState(() => _order = v!),
            ),
            RadioListTile<ReportOrder>(
              title: const Text('حسب البوكسات'),
              value: ReportOrder.byBoxes,
              groupValue: _order,
              onChanged: (v) => setState(() => _order = v!),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generateAndShowPdf,
              icon: _isGenerating
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print),
              label: const Text('إنشاء ومعاينة التقرير'),
            ),
            const SizedBox(height: 8),
            Text(
              'هيفتحلك معاينة، ومنها تقدر تطبع فعليًا أو تحفظها PDF على جهازك.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
