import 'package:flutter/material.dart';
import '../../../../core/engine/hsl_params.dart';
import '../../../../core/engine/tone_params.dart';

class HslPanel extends StatefulWidget {
  final ToneParams toneParams;
  final ValueChanged<ToneParams> onChanged;

  const HslPanel({
    super.key,
    required this.toneParams,
    required this.onChanged,
  });

  @override
  State<HslPanel> createState() => _HslPanelState();
}

class _HslPanelState extends State<HslPanel> {
  HslColor _selectedColor = HslColor.red;

  HslAdjustment get _currentAdj =>
      widget.toneParams.hslAdjustments[_selectedColor] ?? const HslAdjustment();

  void _updateCurrent(HslAdjustment newAdj) {
    final newMap = Map<HslColor, HslAdjustment>.from(widget.toneParams.hslAdjustments);
    newMap[_selectedColor] = newAdj;
    widget.onChanged(widget.toneParams.copyWith(hslAdjustments: newMap));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Color Selection Ribbon
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: HslColor.values.map((color) {
              final isSelected = _selectedColor == color;
              final isModified = widget.toneParams.hslAdjustments[color]?.isModified ?? false;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = color),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.displayColor,
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.displayColor.withOpacity(0.5),
                          blurRadius: 8,
                        )
                    ],
                  ),
                  child: isModified
                      ? Center(
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Hue Slider
        _buildSlider(
          label: 'Hue',
          value: _currentAdj.hue,
          min: -0.5,
          max: 0.5,
          activeColor: _selectedColor.displayColor,
          onChanged: (v) => _updateCurrent(_currentAdj.copyWith(hue: v)),
        ),
        
        // Saturation Slider
        _buildSlider(
          label: 'Saturation',
          value: _currentAdj.saturation,
          min: -1.0,
          max: 1.0,
          activeColor: _selectedColor.displayColor,
          onChanged: (v) => _updateCurrent(_currentAdj.copyWith(saturation: v)),
        ),
        
        // Luminance Slider
        _buildSlider(
          label: 'Luminance',
          value: _currentAdj.luminance,
          min: -1.0,
          max: 1.0,
          activeColor: Colors.grey,
          onChanged: (v) => _updateCurrent(_currentAdj.copyWith(luminance: v)),
        ),
        
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color activeColor,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                activeTrackColor: activeColor,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
                overlayColor: activeColor.withOpacity(0.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value > 0 ? '+${(value * 100).toInt()}' : '${(value * 100).toInt()}',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
