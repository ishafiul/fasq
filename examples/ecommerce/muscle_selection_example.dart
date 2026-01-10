import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;

class MuscleSelectionScreen extends StatefulWidget {
  const MuscleSelectionScreen({super.key});

  @override
  State<MuscleSelectionScreen> createState() => _MuscleSelectionScreenState();
}

class _MuscleSelectionScreenState extends State<MuscleSelectionScreen> {
  final TransformationController _transformationController =
      TransformationController();
  final Set<String> _selectedMuscles = {};
  String? _svgString;

  @override
  void initState() {
    super.initState();
    _loadSvg();
  }

  Future<void> _loadSvg() async {
    final svgString = await DefaultAssetBundle.of(context)
        .loadString('assets/muscle_diagram.svg');
    setState(() {
      _svgString = svgString;
    });
  }

  String _applyMuscleStyles(String svgString) {
    String modified = svgString;
    for (final muscle in _selectedMuscles) {
      modified = modified.replaceAll(
        'id="$muscle" class="muscle"',
        'id="$muscle" class="muscle selected"',
      );
    }
    for (final muscle in _getAllMuscleIds()) {
      if (!_selectedMuscles.contains(muscle)) {
        modified = modified.replaceAll(
          'id="$muscle" class="muscle selected"',
          'id="$muscle" class="muscle"',
        );
      }
    }
    return modified;
  }

  List<String> _getAllMuscleIds() {
    return [
      'chest',
      'shoulder-left',
      'shoulder-right',
      'biceps-left',
      'biceps-right',
      'forearm-left',
      'forearm-right',
      'abs',
      'oblique-left',
      'oblique-right',
      'quad-left',
      'quad-right',
      'adductor-left',
      'adductor-right',
    ];
  }

  void _handleMuscleTap(String muscleId) {
    setState(() {
      if (_selectedMuscles.contains(muscleId)) {
        _selectedMuscles.remove(muscleId);
      } else {
        _selectedMuscles.add(muscleId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Choose Muscle',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _svgString == null
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(
                    transformationController: _transformationController,
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: GestureDetector(
                      onTapDown: (details) => _handleTap(details),
                      child: SvgPicture.string(
                        _applyMuscleStyles(_svgString!),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
          ),
          _buildSelectedMusclesSection(),
          _buildDoneButton(),
        ],
      ),
    );
  }

  void _handleTap(TapDownDetails details) {
    final RenderBox? renderBox =
        context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final muscle = _getMuscleAtPosition(localPosition);
    if (muscle != null) {
      _handleMuscleTap(muscle);
    }
  }

  String? _getMuscleAtPosition(Offset position) {
    final muscles = {
      'chest': const Rect.fromLTWH(160, 120, 80, 70),
      'shoulder-left': const Rect.fromLTWH(110, 105, 40, 30),
      'shoulder-right': const Rect.fromLTWH(250, 105, 40, 30),
      'biceps-left': const Rect.fromLTWH(100, 180, 30, 40),
      'biceps-right': const Rect.fromLTWH(270, 180, 30, 40),
      'forearm-left': const Rect.fromLTWH(95, 260, 20, 40),
      'forearm-right': const Rect.fromLTWH(285, 260, 20, 40),
      'abs': const Rect.fromLTWH(180, 220, 40, 60),
      'oblique-left': const Rect.fromLTWH(135, 240, 25, 70),
      'oblique-right': const Rect.fromLTWH(240, 240, 25, 70),
      'quad-left': const Rect.fromLTWH(155, 380, 20, 150),
      'quad-right': const Rect.fromLTWH(225, 380, 20, 150),
      'adductor-left': const Rect.fromLTWH(170, 450, 15, 60),
      'adductor-right': const Rect.fromLTWH(215, 450, 15, 60),
    };

    for (final entry in muscles.entries) {
      if (entry.value.contains(position)) {
        return entry.key;
      }
    }
    return null;
  }

  Widget _buildSelectedMusclesSection() {
    if (_selectedMuscles.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chosen Muscle',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedMuscles.map((muscle) {
              return Chip(
                label: Text(_formatMuscleName(muscle)),
                backgroundColor: const Color(0xFF2A2A2A),
                labelStyle: const TextStyle(color: Colors.white),
                deleteIcon: const Icon(
                  Icons.close,
                  color: Color(0xFF00FF88),
                  size: 18,
                ),
                onDeleted: () {
                  setState(() => _selectedMuscles.remove(muscle));
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatMuscleName(String muscleId) {
    return muscleId
        .split('-')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Widget _buildDoneButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context, _selectedMuscles.toList());
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00FF88),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }
}

