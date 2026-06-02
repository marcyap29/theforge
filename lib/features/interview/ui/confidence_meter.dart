import 'package:flutter/material.dart';

import '../state/interview_state.dart';

class ConfidenceMeter extends StatelessWidget {
  const ConfidenceMeter({super.key, required this.confidenceMap});

  final Map<ConfidenceDimension, DimensionState> confidenceMap;

  static const _trackColor = Color(0xFF1F2937);
  static const _stateColors = <DimensionState, Color>{
    DimensionState.unknown: Color(0xFF6B7280),
    DimensionState.partial: Color(0xFFE8A04C),
    DimensionState.resolved: Color(0xFF22C55E),
  };
  static const _stateLabels = <DimensionState, String>{
    DimensionState.unknown: 'Unknown',
    DimensionState.partial: 'Partial',
    DimensionState.resolved: 'Resolved',
  };

  @override
  Widget build(BuildContext context) {
    final resolvedCount = confidenceMap.values
        .where((s) => s == DimensionState.resolved)
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF141416),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'CONFIDENCE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              Text(
                '$resolvedCount / 8 resolved',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Menlo',
                  color: Color(0xFFE5E5E7),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final dim in ConfidenceDimension.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: _DimensionBar(
                dimension: dim,
                state: confidenceMap[dim] ?? DimensionState.unknown,
              ),
            ),
        ],
      ),
    );
  }
}

class _DimensionBar extends StatelessWidget {
  const _DimensionBar({required this.dimension, required this.state});

  final ConfidenceDimension dimension;
  final DimensionState state;

  @override
  Widget build(BuildContext context) {
    final color = ConfidenceMeter._stateColors[state]!;
    final label = ConfidenceMeter._stateLabels[state]!;
    final fillFactor = switch (state) {
      DimensionState.resolved => 1.0,
      DimensionState.partial => 0.5,
      DimensionState.unknown => 0.0,
    };

    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Text(
            dimension.label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFE5E5E7),
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fillFactor,
              minHeight: 8,
              backgroundColor: ConfidenceMeter._trackColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            label,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Menlo',
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
