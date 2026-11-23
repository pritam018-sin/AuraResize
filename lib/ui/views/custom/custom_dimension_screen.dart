// Copyright (C) 2026 AuraStudio Corporation • Pritam
// AuraResize - Minimalist Custom Dimension Studio

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../models/exam_preset_model.dart';
import '../../../theme/sarkari_theme.dart';
import '../crop/sarkari_crop_studio_screen.dart';

class CustomDimensionScreen extends StatefulWidget {
  final File? initialFile;

  const CustomDimensionScreen({super.key, this.initialFile});

  static Future<void> open(BuildContext context, {File? file}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomDimensionScreen(initialFile: file),
      ),
    );
  }

  @override
  State<CustomDimensionScreen> createState() => _CustomDimensionScreenState();
}

class _CustomDimensionScreenState extends State<CustomDimensionScreen> {
  File? _selectedFile;
  final TextEditingController _widthCtrl = TextEditingController(text: '3.5');
  final TextEditingController _heightCtrl = TextEditingController(text: '4.5');
  final TextEditingController _minKbCtrl = TextEditingController(text: '20');
  final TextEditingController _maxKbCtrl = TextEditingController(text: '50');

  DimensionUnit _selectedUnit = DimensionUnit.cm;
  int _selectedDpi = 200;
  bool _addNameDateBanner = false;

  @override
  void initState() {
    super.initState();
    _selectedFile = widget.initialFile;
  }

  @override
  void dispose() {
    _widthCtrl.dispose();
    _heightCtrl.dispose();
    _minKbCtrl.dispose();
    _maxKbCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source);
    if (picked != null && mounted) {
      setState(() => _selectedFile = File(picked.path));
    }
  }

  int get _calculatedPixelW {
    final w = double.tryParse(_widthCtrl.text) ?? 3.5;
    switch (_selectedUnit) {
      case DimensionUnit.pixel:
        return w.round();
      case DimensionUnit.cm:
        return ((w / 2.54) * _selectedDpi).round();
      case DimensionUnit.mm:
        return ((w / 25.4) * _selectedDpi).round();
      case DimensionUnit.inch:
        return (w * _selectedDpi).round();
    }
  }

  int get _calculatedPixelH {
    final h = double.tryParse(_heightCtrl.text) ?? 4.5;
    switch (_selectedUnit) {
      case DimensionUnit.pixel:
        return h.round();
      case DimensionUnit.cm:
        return ((h / 2.54) * _selectedDpi).round();
      case DimensionUnit.mm:
        return ((h / 25.4) * _selectedDpi).round();
      case DimensionUnit.inch:
        return (h * _selectedDpi).round();
    }
  }

  void _proceedToCrop() {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select an image first')),
      );
      return;
    }

    final w = double.tryParse(_widthCtrl.text) ?? 3.5;
    final h = double.tryParse(_heightCtrl.text) ?? 4.5;
    final minKb = int.tryParse(_minKbCtrl.text) ?? 20;
    final maxKb = int.tryParse(_maxKbCtrl.text) ?? 50;

    final customPreset = ExamPresetModel(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      category: 'Custom',
      examName: 'Custom $w × $h ${_selectedUnit.symbol}',
      itemType: 'Custom',
      width: w,
      height: h,
      unit: _selectedUnit,
      dpi: _selectedDpi,
      minKb: minKb,
      maxKb: maxKb,
      requiresNameDate: _addNameDateBanner,
    );

    SarkariCropStudioScreen.open(context, file: _selectedFile!, preset: customPreset);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SarkariTheme.darkBackground,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Custom Dimension'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Photo Picker Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SarkariTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SarkariTheme.surfaceBorder),
            ),
            child: Column(
              children: [
                if (_selectedFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedFile!, height: 160, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SarkariTheme.textPrimary,
                          side: const BorderSide(color: SarkariTheme.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.photo_library_outlined, size: 16),
                        label: const Text('Gallery', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SarkariTheme.textPrimary,
                          side: const BorderSide(color: SarkariTheme.surfaceBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16),
                        label: const Text('Camera', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ] else ...[
                  InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: SarkariTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SarkariTheme.surfaceBorder, style: BorderStyle.solid),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, color: SarkariTheme.cyanAccent, size: 28),
                            SizedBox(height: 6),
                            Text(
                              'Tap to Select Image',
                              style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Physical Dimension Inputs
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SarkariTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SarkariTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('DIMENSIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SarkariTheme.textMuted, letterSpacing: 0.8)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: SarkariTheme.surfaceElevated,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: DimensionUnit.values.map((u) {
                          final isSel = _selectedUnit == u;
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() {
                                _selectedUnit = u;
                                if (u == DimensionUnit.cm) {
                                  _widthCtrl.text = '3.5';
                                  _heightCtrl.text = '4.5';
                                } else if (u == DimensionUnit.mm) {
                                  _widthCtrl.text = '35';
                                  _heightCtrl.text = '45';
                                } else if (u == DimensionUnit.inch) {
                                  _widthCtrl.text = '2.0';
                                  _heightCtrl.text = '2.0';
                                } else if (u == DimensionUnit.pixel) {
                                  _widthCtrl.text = '350';
                                  _heightCtrl.text = '450';
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSel ? SarkariTheme.cyanAccent : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                u.symbol,
                                style: TextStyle(
                                  color: isSel ? Colors.black : SarkariTheme.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Width', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 11)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _widthCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              suffixText: _selectedUnit.symbol,
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Height', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 11)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _heightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              suffixText: _selectedUnit.symbol,
                              isDense: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Calculated Output Resolution
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: SarkariTheme.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Text('Target Output:', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 11)),
                      const Spacer(),
                      Text(
                        '$_calculatedPixelW × $_calculatedPixelH px',
                        style: const TextStyle(color: SarkariTheme.cyanAccent, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. DPI & Target File Size (KB)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SarkariTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SarkariTheme.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('DPI & QUALITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SarkariTheme.textMuted, letterSpacing: 0.8)),
                    const Spacer(),
                    Row(
                      children: [100, 150, 200, 300].map((dpi) {
                        final isSel = _selectedDpi == dpi;
                        return Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: InkWell(
                            onTap: () => setState(() => _selectedDpi = dpi),
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSel ? SarkariTheme.cyanAccent : SarkariTheme.surfaceElevated,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$dpi',
                                style: TextStyle(
                                  color: isSel ? Colors.black : SarkariTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Min Size (KB)', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 11)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _minKbCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                            decoration: const InputDecoration(suffixText: 'KB', isDense: true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Max Size (KB)', style: TextStyle(color: SarkariTheme.textSecondary, fontSize: 11)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _maxKbCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: SarkariTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                            decoration: const InputDecoration(suffixText: 'KB', isDense: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 4. Name & Date of Photo (DOP) Banner Switch
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SarkariTheme.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SarkariTheme.surfaceBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_calendar_outlined, color: SarkariTheme.cyanAccent, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Name & Date of Photo (DOP) Banner',
                        style: TextStyle(color: SarkariTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Prints white banner at bottom with name & photo date',
                        style: TextStyle(color: SarkariTheme.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _addNameDateBanner,
                  activeColor: SarkariTheme.cyanAccent,
                  onChanged: (val) {
                    setState(() => _addNameDateBanner = val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button
          FilledButton(
            onPressed: _proceedToCrop,
            style: FilledButton.styleFrom(
              backgroundColor: SarkariTheme.cyanAccent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Continue to Crop', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
