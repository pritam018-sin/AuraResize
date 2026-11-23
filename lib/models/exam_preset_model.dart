// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Clean Technical Dimension Presets

enum DimensionUnit {
  cm('cm', 'Centimeters'),
  mm('mm', 'Millimeters'),
  inch('in', 'Inches'),
  pixel('px', 'Pixels');

  final String symbol;
  final String label;
  const DimensionUnit(this.symbol, this.label);
}

class ExamPresetModel {
  final String id;
  final String category; // 'Exams', 'Banking', 'Entrances', 'IDs', 'Passport/Visa'
  final String examName;
  final String itemType; // 'Photo', 'Signature', 'Thumb', 'Document'
  final double width;
  final double height;
  final DimensionUnit unit;
  final int dpi;
  final int minKb;
  final int maxKb;
  final bool requiresNameDate;
  final String notes;

  const ExamPresetModel({
    required this.id,
    required this.category,
    required this.examName,
    required this.itemType,
    required this.width,
    required this.height,
    required this.unit,
    this.dpi = 200,
    required this.minKb,
    required this.maxKb,
    this.requiresNameDate = false,
    this.notes = '',
  });

  int get pixelWidth {
    switch (unit) {
      case DimensionUnit.pixel:
        return width.round();
      case DimensionUnit.inch:
        return (width * dpi).round();
      case DimensionUnit.cm:
        return ((width / 2.54) * dpi).round();
      case DimensionUnit.mm:
        return ((width / 25.4) * dpi).round();
    }
  }

  int get pixelHeight {
    switch (unit) {
      case DimensionUnit.pixel:
        return height.round();
      case DimensionUnit.inch:
        return (height * dpi).round();
      case DimensionUnit.cm:
        return ((height / 2.54) * dpi).round();
      case DimensionUnit.mm:
        return ((height / 25.4) * dpi).round();
    }
  }

  String get dimensionSummary =>
      '${width.toStringAsFixed(width.truncateToDouble() == width ? 0 : 1)} × ${height.toStringAsFixed(height.truncateToDouble() == height ? 0 : 1)} ${unit.symbol}';
  String get kbSummary => '$minKb - $maxKb KB';
  double get aspectRatio => width / height;

  static const List<ExamPresetModel> presets = [
    ExamPresetModel(
      id: 'ssc_photo',
      category: 'Exams',
      examName: 'SSC CGL / CHSL / MTS',
      itemType: 'Photo',
      width: 3.5,
      height: 4.5,
      unit: DimensionUnit.cm,
      dpi: 200,
      minKb: 20,
      maxKb: 50,
      requiresNameDate: true,
      notes: '3.5 × 4.5 cm, DOP stamp supported',
    ),
    ExamPresetModel(
      id: 'ssc_sig',
      category: 'Exams',
      examName: 'SSC CGL / CHSL / MTS',
      itemType: 'Signature',
      width: 4.0,
      height: 2.0,
      unit: DimensionUnit.cm,
      dpi: 200,
      minKb: 10,
      maxKb: 20,
      notes: '4.0 × 2.0 cm, pure white background',
    ),
    ExamPresetModel(
      id: 'upsc_photo',
      category: 'Exams',
      examName: 'UPSC Civil Services',
      itemType: 'Photo',
      width: 3.5,
      height: 4.5,
      unit: DimensionUnit.cm,
      dpi: 300,
      minKb: 20,
      maxKb: 300,
      requiresNameDate: true,
      notes: '3.5 × 4.5 cm, high resolution 300 DPI',
    ),
    ExamPresetModel(
      id: 'upsc_sig',
      category: 'Exams',
      examName: 'UPSC Civil Services',
      itemType: 'Signature',
      width: 3.5,
      height: 1.5,
      unit: DimensionUnit.cm,
      dpi: 300,
      minKb: 20,
      maxKb: 300,
      notes: '3.5 × 1.5 cm signature',
    ),
    ExamPresetModel(
      id: 'ibps_photo',
      category: 'Banking',
      examName: 'IBPS / SBI PO & Clerk',
      itemType: 'Photo',
      width: 4.5,
      height: 3.5,
      unit: DimensionUnit.cm,
      dpi: 200,
      minKb: 20,
      maxKb: 50,
      notes: '200 × 230 px standard frame',
    ),
    ExamPresetModel(
      id: 'ibps_sig',
      category: 'Banking',
      examName: 'IBPS / SBI PO & Clerk',
      itemType: 'Signature',
      width: 140,
      height: 60,
      unit: DimensionUnit.pixel,
      dpi: 200,
      minKb: 10,
      maxKb: 20,
      notes: '140 × 60 px black ink',
    ),
    ExamPresetModel(
      id: 'ibps_thumb',
      category: 'Banking',
      examName: 'IBPS / SBI Left Thumb',
      itemType: 'Thumb',
      width: 240,
      height: 240,
      unit: DimensionUnit.pixel,
      dpi: 200,
      minKb: 20,
      maxKb: 50,
      notes: '240 × 240 px clean white',
    ),
    ExamPresetModel(
      id: 'neet_photo',
      category: 'Entrances',
      examName: 'NTA NEET / JEE Main',
      itemType: 'Photo',
      width: 3.5,
      height: 4.5,
      unit: DimensionUnit.cm,
      dpi: 300,
      minKb: 10,
      maxKb: 200,
      requiresNameDate: true,
      notes: 'White background, 80% face coverage',
    ),
    ExamPresetModel(
      id: 'neet_postcard',
      category: 'Entrances',
      examName: 'NTA NEET Postcard',
      itemType: 'Photo',
      width: 4.0,
      height: 6.0,
      unit: DimensionUnit.inch,
      dpi: 200,
      minKb: 10,
      maxKb: 200,
      requiresNameDate: true,
      notes: '4 × 6 inch admit postcard',
    ),
    ExamPresetModel(
      id: 'neet_sig',
      category: 'Entrances',
      examName: 'NTA NEET / JEE Main',
      itemType: 'Signature',
      width: 3.5,
      height: 1.5,
      unit: DimensionUnit.cm,
      dpi: 200,
      minKb: 4,
      maxKb: 30,
      notes: '3.5 × 1.5 cm running handwriting',
    ),
    ExamPresetModel(
      id: 'rrb_photo',
      category: 'Exams',
      examName: 'Railways RRB NTPC / Group D',
      itemType: 'Photo',
      width: 35,
      height: 45,
      unit: DimensionUnit.mm,
      dpi: 200,
      minKb: 20,
      maxKb: 50,
      notes: '35 × 45 mm',
    ),
    ExamPresetModel(
      id: 'pan_photo',
      category: 'IDs',
      examName: 'PAN Card (NSDL / UTI)',
      itemType: 'Photo',
      width: 213,
      height: 213,
      unit: DimensionUnit.pixel,
      dpi: 300,
      minKb: 10,
      maxKb: 50,
      notes: '213 × 213 px @ 300 DPI',
    ),
    ExamPresetModel(
      id: 'pan_sig',
      category: 'IDs',
      examName: 'PAN Card (NSDL / UTI)',
      itemType: 'Signature',
      width: 4.5,
      height: 2.0,
      unit: DimensionUnit.cm,
      dpi: 300,
      minKb: 5,
      maxKb: 20,
      notes: '4.5 × 2.0 cm @ 300 DPI',
    ),
    ExamPresetModel(
      id: 'passport_std',
      category: 'Passport/Visa',
      examName: 'Standard Passport Photo',
      itemType: 'Photo',
      width: 3.5,
      height: 4.5,
      unit: DimensionUnit.cm,
      dpi: 300,
      minKb: 20,
      maxKb: 100,
      notes: '35 × 45 mm international standard',
    ),
    ExamPresetModel(
      id: 'visa_square',
      category: 'Passport/Visa',
      examName: 'US / Schengen Visa (2x2")',
      itemType: 'Photo',
      width: 2.0,
      height: 2.0,
      unit: DimensionUnit.inch,
      dpi: 300,
      minKb: 50,
      maxKb: 240,
      notes: 'Square 2 × 2 inches (600 × 600 px)',
    ),
  ];
}
