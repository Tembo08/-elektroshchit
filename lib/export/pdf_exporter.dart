import 'dart:typed_data';

import 'package:electrical_core/electrical_core.dart' as core;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Экспорт расчёта в PDF: сводка, однолинейная схема, проверки,
/// спецификация. Шрифт с кириллицей передаётся снаружи (из assets),
/// чтобы документ одинаково выглядел на телефоне и на десктопе.
class PdfExporter {
  final core.CalculationResult result;
  final String projectName;
  final String? details;
  final Uint8List regularFont;
  final Uint8List? boldFont;
  final DateTime date;

  PdfExporter({
    required this.result,
    required this.projectName,
    required this.regularFont,
    this.boldFont,
    this.details,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  static const _ink = PdfColor.fromInt(0xFF1B1F26);
  static const _muted = PdfColor.fromInt(0xFF6B7280);
  static const _line = PdfColor.fromInt(0xFFCBD2DC);
  static const _phase = PdfColor.fromInt(0xFFD64545);
  static const _accent = PdfColor.fromInt(0xFF1F5FBF);
  static const _warn = PdfColor.fromInt(0xFFB7791F);
  static const _error = PdfColor.fromInt(0xFFC0392B);

  Future<Uint8List> build() async {
    final base = pw.Font.ttf(ByteData.view(regularFont.buffer));
    final bold = boldFont != null
        ? pw.Font.ttf(ByteData.view(boldFont!.buffer))
        : base;

    final doc = pw.Document(
      title: 'Электрощит — $projectName',
      author: 'Электрощит',
      subject: 'Расчёт щита (черновик)',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 26),
        theme: pw.ThemeData.withFont(base: base, bold: bold),
        header: (context) => context.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text(
                  '${projectName.toUpperCase()} · расчёт щита',
                  style: const pw.TextStyle(fontSize: 9, color: _muted),
                ),
              ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 6),
          child: pw.Text(
            'стр. ${context.pageNumber} из ${context.pagesCount} · '
            '${_dateStr()} · черновик, требует проверки электриком',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        build: (context) => [
          _title(),
          if (result.issues.any((i) => i.isError)) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFDECEA),
                border: pw.Border.all(color: _error, width: 0.8),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'НЕ ДЛЯ МОНТАЖА',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: _error,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'В расчёте есть ошибки — исправьте их и пересчитайте перед '
                    'закупкой и монтажом.',
                    style: const pw.TextStyle(fontSize: 8, color: _ink),
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 12),
          _summary(),
          pw.SizedBox(height: 14),
          _sectionTitle('Однолинейная схема'),
          pw.SizedBox(height: 6),
          _scheme(context),
          pw.SizedBox(height: 14),
          _sectionTitle('Проверки'),
          pw.SizedBox(height: 6),
          _issues(),
          pw.SizedBox(height: 14),
          _sectionTitle('Линии'),
          pw.SizedBox(height: 6),
          _linesTable(),
          pw.SizedBox(height: 14),
          _sectionTitle('Спецификация (черновик)'),
          pw.SizedBox(height: 6),
          _materialsTable(),
        ],
      ),
    );

    return doc.save();
  }

  String _dateStr() =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  // ───────────────────────── шапка ─────────────────────────
  pw.Widget _title() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          projectName,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        if (details != null) ...[
          pw.SizedBox(height: 3),
          pw.Text(
            details!,
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Container(height: 2, color: _accent),
      ],
    );
  }

  // ───────────────────────── сводка ─────────────────────────
  pw.Widget _summary() {
    final panel = result.panel;
    final input = result.inputGroup;
    final balance = result.phaseBalance;

    pw.Widget cell(String value, String label) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        );

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              cell('${panel.totalCalculatedPowerKw.toStringAsFixed(1)} кВт',
                  'расчётная мощность'),
              cell('${(panel.loadFactor * 100).round()} %', 'загрузка ввода'),
              cell('${panel.totalDinModules}', 'DIN-модулей'),
              cell(panel.recommendedPanelSize.replaceAll(' модулей', ''),
                  'корпус, модулей'),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Divider(height: 1, color: _line),
          pw.SizedBox(height: 8),
          pw.Text(
            'Установленная мощность ${panel.installedPowerKw.toStringAsFixed(1)} кВт'
            ' · коэффициент спроса −${panel.demandSavingKw.toStringAsFixed(1)} кВт',
            style: const pw.TextStyle(fontSize: 8.5, color: _muted),
          ),
          if (input != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Ввод: ${input.breakerAmps} А (${input.poles}P), '
              '${input.cableType}, УЗО ${input.rcdMa} мА'
              '${input.rcdType == null ? '' : ' тип ${input.rcdType}'}',
              style: const pw.TextStyle(fontSize: 9, color: _ink),
            ),
          ],
          if (balance != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              'Фазы: L1 ${balance.l1Kw.toStringAsFixed(1)} · '
              'L2 ${balance.l2Kw.toStringAsFixed(1)} · '
              'L3 ${balance.l3Kw.toStringAsFixed(1)} кВт '
              '(перекос ${balance.imbalancePercent.toStringAsFixed(0)} %)',
              style: const pw.TextStyle(fontSize: 9, color: _ink),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _sectionTitle(String text) => pw.Row(
        children: [
          pw.Container(width: 3, height: 12, color: _accent),
          pw.SizedBox(width: 6),
          pw.Text(
            text,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      );

  // ───────────────────── однолинейная схема ─────────────────────
  pw.Widget _scheme(pw.Context context) {
    final groups = result.groups;
    final input = result.inputGroup;
    final phases = _phasesOf(groups);

    const width = 539.0;
    const busY = 46.0;
    const boxH = 22.0;
    const gap = 6.0;
    final columnCount = phases.isEmpty ? 1 : phases.length;
    final columnW = width / columnCount;

    // высота — по самой населённой фазе
    var maxRows = 1;
    for (final p in phases) {
      final n = groups.where((g) => _phaseOf(g) == p).length;
      if (n > maxRows) maxRows = n;
    }
    final height = busY + 24 + maxRows * (boxH + gap) + 6;

    return pw.Container(
      width: width,
      height: height,
      child: pw.Stack(
        children: [
          // ввод и шина
          pw.Positioned(
            left: 0,
            top: 0,
            child: pw.Container(
              width: 150,
              padding: const pw.EdgeInsets.all(4),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _accent, width: 1.2),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Ввод ${input?.breakerAmps ?? '-'} А',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    input == null
                        ? ''
                        : '${input.cableType} · УЗО ${input.rcdMa} мА',
                    style: const pw.TextStyle(fontSize: 7, color: _muted),
                  ),
                ],
              ),
            ),
          ),
          pw.Positioned(
            left: 0,
            top: busY,
            child: pw.Container(width: width, height: 2.5, color: _ink),
          ),
          // отводы и блоки линий
          for (var c = 0; c < phases.length; c++) ...[
            pw.Positioned(
              left: columnW * c + columnW / 2 - 0.6,
              top: busY,
              child: pw.Container(width: 1.2, height: 18, color: _phase),
            ),
            pw.Positioned(
              left: columnW * c + 4,
              top: busY + 18,
              child: pw.Text(
                _phaseLabel(phases[c]),
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: _phase,
                ),
              ),
            ),
            ...groups
                .where((g) => _phaseOf(g) == phases[c])
                .toList()
                .asMap()
                .entries
                .map((entry) {
              final i = entry.key;
              final g = entry.value;
              return pw.Positioned(
                left: columnW * c + 4,
                top: busY + 24 + i * (boxH + gap),
                child: pw.Container(
                  width: columnW - 8,
                  height: boxH,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: g.warnings.isEmpty ? _accent : _warn,
                    ),
                    borderRadius: pw.BorderRadius.circular(3),
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _shortName(g),
                        maxLines: 1,
                        style: const pw.TextStyle(fontSize: 6.5),
                      ),
                      pw.Text(
                        '${g.breakerAmps} А · ${g.cableSectionMm2} мм² · '
                        '${g.dinModules} DIN',
                        maxLines: 1,
                        style: const pw.TextStyle(fontSize: 5.5, color: _muted),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  List<String> _phasesOf(List<core.CircuitGroup> groups) {
    final found = <String>{};
    for (final g in groups) {
      found.add(_phaseOf(g));
    }
    if (found.isEmpty) return const [];
    const order = ['L1', 'L2', 'L3', 'L', '3Ф'];
    final sorted = order.where(found.contains).toList();
    for (final f in found) {
      if (!sorted.contains(f)) sorted.add(f);
    }
    return sorted;
  }

  String _phaseOf(core.CircuitGroup g) {
    final p = g.phase ?? 'L';
    if (p.contains('-')) return '3Ф';
    return p;
  }

  String _phaseLabel(String p) => switch (p) {
        'L1' => 'L1',
        'L2' => 'L2',
        'L3' => 'L3',
        '3Ф' => '3 фазы',
        _ => '1 фаза',
      };

  String _shortName(core.CircuitGroup g) =>
      g.name.replaceFirst(RegExp(r'^Гр\. \d+ — '), '');

  // ───────────────────────── проверки ─────────────────────────
  pw.Widget _issues() {
    if (result.issues.isEmpty) {
      return pw.Text('Замечаний нет', style: const pw.TextStyle(fontSize: 9));
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: result.issues.take(12).map((issue) {
        final color = switch (issue.severity) {
          core.IssueSeverity.error => _error,
          core.IssueSeverity.warning => _warn,
          core.IssueSeverity.info => _muted,
        };
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 3, right: 4),
                width: 4,
                height: 4,
                decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
              ),
              pw.Expanded(
                child: pw.Text(
                  issue.message,
                  style: pw.TextStyle(fontSize: 8.5, color: color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ───────────────────────── линии ─────────────────────────
  pw.Widget _linesTable() {
    final rows = <List<String>>[
      ['№', 'Линия', 'P, кВт', 'I, А', 'Авт., А', 'Кабель', 'УЗО', 'DIN'],
    ];
    for (final g in result.groups) {
      final number = RegExp(r'^Гр\. (\d+)').firstMatch(g.name)?.group(1) ?? '—';
      final name = g.name.replaceFirst(RegExp(r'^Гр\. \d+ — '), '');
      final rcd = g.isDifferentialBreaker
          ? 'диф ${g.rcdMa}'
          : g.hasRcd && g.rcdMa != null
              ? '${g.rcdMa}${g.rcdType == null ? '' : ' ${g.rcdType}'}'
              : g.parentRcdId != null
                  ? 'общее'
                  : '—';
      rows.add([
        number,
        name,
        g.totalPowerKw.toStringAsFixed(2),
        g.calculatedCurrentA.toStringAsFixed(1),
        '${g.breakerAmps}',
        '${g.cableSectionMm2} мм²',
        rcd,
        '${g.dinModules}',
      ]);
    }

    return pw.TableHelper.fromTextArray(
      data: rows,
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEF2F8)),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
      border: pw.TableBorder.all(color: _line, width: 0.4),
      columnWidths: {
        0: const pw.FixedColumnWidth(18),
        2: const pw.FixedColumnWidth(38),
        3: const pw.FixedColumnWidth(32),
        4: const pw.FixedColumnWidth(38),
        5: const pw.FixedColumnWidth(50),
        6: const pw.FixedColumnWidth(52),
        7: const pw.FixedColumnWidth(26),
      },
    );
  }

  // ───────────────────────── спецификация ─────────────────────────
  pw.Widget _materialsTable() {
    final rows = <List<String>>[
      ['Наименование', 'Кол-во', 'Ед.'],
      for (final m in result.panel.materials)
        [
          m.name,
          m.quantity % 1 == 0
              ? m.quantity.toInt().toString()
              : m.quantity.toStringAsFixed(1),
          m.unit,
        ],
    ];
    return pw.TableHelper.fromTextArray(
      data: rows,
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEEF2F8)),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2.5),
      border: pw.TableBorder.all(color: _line, width: 0.4),
      columnWidths: {
        1: const pw.FixedColumnWidth(44),
        2: const pw.FixedColumnWidth(26),
      },
    );
  }
}
