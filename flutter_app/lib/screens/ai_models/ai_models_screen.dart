import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/ai_models_service.dart';
import '../../core/theme/app_theme.dart';

class AIModelsScreen extends StatefulWidget {
  const AIModelsScreen({super.key});

  @override
  State<AIModelsScreen> createState() => _AIModelsScreenState();
}

enum _AIModelKind { colon, breast }

class _AIModelSpec {
  final _AIModelKind kind;
  final String tabTitle;
  final String name;
  final String description;
  final String inputType;
  final Color color;

  const _AIModelSpec({
    required this.kind,
    required this.tabTitle,
    required this.name,
    required this.description,
    required this.inputType,
    required this.color,
  });
}

const _modelSpecs = <_AIModelSpec>[
  _AIModelSpec(
    kind: _AIModelKind.colon,
    tabTitle: 'Colon Pathology',
    name: 'Colon Pathology',
    description:
        'Classifies colon tissue images across common pathology categories.',
    inputType: 'Pathology or histology image',
    color: Color(0xFF0891B2),
  ),
  _AIModelSpec(
    kind: _AIModelKind.breast,
    tabTitle: 'Breast Cancer',
    name: 'Breast Cancer',
    description:
        'Analyzes breast pathology images for normal or cancer patterns.',
    inputType: 'Breast pathology image',
    color: Color(0xFFD97706),
  ),
];

class _AIModelsScreenState extends State<AIModelsScreen> {
  final _picker = ImagePicker();

  _AIModelKind _selectedKind = _AIModelKind.colon;
  File? _selectedImage;
  AIModelPrediction? _result;
  AIModelsAvailability? _availability;
  String? _errorMessage;
  bool _loadingStatus = true;
  bool _analyzing = false;

  _AIModelSpec get _selectedSpec =>
      _modelSpecs.firstWhere((spec) => spec.kind == _selectedKind);

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    setState(() => _loadingStatus = true);
    try {
      final availability = await AIModelsService.getModelsStatus();
      if (!mounted) return;
      setState(() => _availability = availability);
    } catch (_) {
      if (!mounted) return;
      setState(() => _availability = null);
    } finally {
      if (mounted) setState(() => _loadingStatus = false);
    }
  }

  void _selectModel(_AIModelKind kind) {
    if (_selectedKind == kind || _analyzing) return;
    setState(() {
      _selectedKind = kind;
      _selectedImage = null;
      _result = null;
      _errorMessage = null;
    });
  }

  bool? _readyFor(_AIModelKind kind) {
    if (_loadingStatus) return null;
    switch (kind) {
      case _AIModelKind.colon:
        return _availability?.colonPathologyReady;
      case _AIModelKind.breast:
        return _availability?.breastCancerReady;
    }
  }

  Future<void> _chooseImage() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(isDark: isDark),
    );
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _selectedImage = File(picked.path);
        _result = null;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not open the image picker. Please try again.';
      });
    }
  }

  Future<void> _analyze() async {
    final image = _selectedImage;
    if (image == null || _analyzing) return;

    setState(() {
      _analyzing = true;
      _result = null;
      _errorMessage = null;
    });

    try {
      final prediction =
          _selectedKind == _AIModelKind.colon
              ? await AIModelsService.predictColonImage(image)
              : await AIModelsService.predictBreastImage(image);
      if (!mounted) return;
      setState(() {
        if (prediction.success) {
          _result = prediction;
        } else {
          _errorMessage = 'Model is not ready yet. Please try again later.';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Could not analyze this image. Please check your connection and try again.';
      });
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final spec = _selectedSpec;

    return Scaffold(
      appBar: AppBar(title: const Text('AI Models')),
      body: RefreshIndicator(
        onRefresh: _loadAvailability,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HeaderCard(isDark: isDark),
            const SizedBox(height: 16),
            _ModelSwitcher(
              selectedKind: _selectedKind,
              onSelect: _selectModel,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _ModelInfoCard(
              spec: spec,
              isDark: isDark,
              ready: _readyFor(spec.kind),
              loadingStatus: _loadingStatus,
            ),
            const SizedBox(height: 16),
            _UploadCard(
              spec: spec,
              isDark: isDark,
              image: _selectedImage,
              analyzing: _analyzing,
              onChooseImage: _chooseImage,
              onClearImage:
                  () => setState(() {
                    _selectedImage = null;
                    _result = null;
                    _errorMessage = null;
                  }),
              onAnalyze: _analyze,
            ),
            if (_analyzing) ...[
              const SizedBox(height: 16),
              _LoadingCard(isDark: isDark),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _errorMessage!, isDark: isDark),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              _ResultCard(result: _result!, isDark: isDark),
            ],
            const SizedBox(height: 16),
            _DisclaimerCard(isDark: isDark),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final bool isDark;

  const _HeaderCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              isDark
                  ? [const Color(0xFF0D2244), const Color(0xFF1A1A2E)]
                  : [AppColors.secondary, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: isDark ? 0.2 : 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.model_training_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Models',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Choose a medical AI model and upload an image for analysis.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelSwitcher extends StatelessWidget {
  final _AIModelKind selectedKind;
  final ValueChanged<_AIModelKind> onSelect;
  final bool isDark;

  const _ModelSwitcher({
    required this.selectedKind,
    required this.onSelect,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : AppColors.lightGray,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children:
            _modelSpecs
                .map(
                  (spec) => Expanded(
                    child: _ModelSegment(
                      spec: spec,
                      selected: selectedKind == spec.kind,
                      onTap: () => onSelect(spec.kind),
                      isDark: isDark,
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _ModelSegment extends StatelessWidget {
  final _AIModelSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  const _ModelSegment({
    required this.spec,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.biotech_rounded,
              size: 16,
              color:
                  selected
                      ? Colors.white
                      : (isDark ? Colors.white54 : AppColors.textMuted),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                spec.tabTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      selected
                          ? Colors.white
                          : (isDark ? Colors.white54 : AppColors.textMuted),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelInfoCard extends StatelessWidget {
  final _AIModelSpec spec;
  final bool isDark;
  final bool? ready;
  final bool loadingStatus;

  const _ModelInfoCard({
    required this.spec,
    required this.isDark,
    required this.ready,
    required this.loadingStatus,
  });

  Color get _statusColor {
    if (loadingStatus || ready == null) return AppColors.textMuted;
    return ready! ? const Color(0xFF16A34A) : const Color(0xFFD97706);
  }

  String get _statusLabel {
    if (loadingStatus) return 'Checking';
    if (ready == true) return 'Available';
    if (ready == false) return 'Model not ready';
    return 'Not checked';
  }

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: spec.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.model_training_rounded,
                  color: spec.color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  spec.name,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusChip(label: _statusLabel, color: _statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            spec.description,
            style: TextStyle(
              color: isDark ? Colors.white60 : AppColors.textMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(
            icon: Icons.image_search_rounded,
            label: 'Input type',
            value: spec.inputType,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final _AIModelSpec spec;
  final bool isDark;
  final File? image;
  final bool analyzing;
  final VoidCallback onChooseImage;
  final VoidCallback onClearImage;
  final VoidCallback onAnalyze;

  const _UploadCard({
    required this.spec,
    required this.isDark,
    required this.image,
    required this.analyzing,
    required this.onChooseImage,
    required this.onClearImage,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = image != null;
    return _SurfaceCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_upload_rounded, color: spec.color, size: 22),
              const SizedBox(width: 8),
              Text(
                'Upload image',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Use a clear medical/pathology image for the selected model.',
            style: TextStyle(
              color: isDark ? Colors.white54 : AppColors.textMuted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          if (hasImage)
            _ImagePreview(
              image: image!,
              onClear: analyzing ? null : onClearImage,
            )
          else
            _EmptyUploadBox(color: spec.color, onTap: onChooseImage),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: analyzing ? null : onChooseImage,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(hasImage ? 'Change Image' : 'Choose Image'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: !hasImage || analyzing ? null : onAnalyze,
            icon:
                analyzing
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.analytics_rounded),
            label: Text(analyzing ? 'Analyzing...' : 'Analyze'),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  final File image;
  final VoidCallback? onClear;

  const _ImagePreview({required this.image, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.file(
            image,
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        GestureDetector(
          onTap: onClear,
          child: Container(
            margin: const EdgeInsets.all(8),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color:
                  onClear == null
                      ? Colors.black26
                      : Colors.black.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyUploadBox extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _EmptyUploadBox({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.08 : 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.add_photo_alternate_rounded, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              'Select a medical image',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'JPG or PNG pathology images work best.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final AIModelPrediction result;
  final bool isDark;

  const _ResultCard({required this.result, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prediction Result',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Top model output',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(
                alpha: isDark ? 0.12 : 0.08,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    result.predictedClass ?? 'Prediction unavailable',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  _formatConfidence(result.confidence),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (result.topPredictions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Top predictions',
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ...result.topPredictions.map(
              (prediction) =>
                  _PredictionRow(prediction: prediction, isDark: isDark),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  final AITopPrediction prediction;
  final bool isDark;

  const _PredictionRow({required this.prediction, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final progress = _confidenceProgress(prediction.confidence);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  prediction.className,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatConfidence(prediction.confidence),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor:
                  isDark ? const Color(0xFF13131E) : AppColors.lightGray,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.secondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final bool isDark;

  const _LoadingCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      isDark: isDark,
      child: const Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Analyzing your medical image...',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final bool isDark;

  const _ErrorCard({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isDark ? Colors.white70 : AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  final bool isDark;

  const _DisclaimerCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isDark
                ? const Color(0xFF0891B2).withValues(alpha: 0.12)
                : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0891B2).withValues(alpha: 0.28),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF0891B2)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'This AI result is for medical assistance only and is not a final diagnosis.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  final bool isDark;

  const _ImageSourceSheet({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E2E) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightGray.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Select Image',
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.secondary,
                  ),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: TextStyle(color: textColor),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F0FE),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.secondary,
                  ),
                ),
                title: Text('Take Photo', style: TextStyle(color: textColor)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: isDark ? Colors.white60 : AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _SurfaceCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _formatConfidence(double value) {
  final percent = value <= 1 ? value * 100 : value;
  return '${percent.clamp(0, 100).round()}%';
}

double _confidenceProgress(double value) {
  final normalized = value <= 1 ? value : value / 100;
  return normalized.clamp(0, 1).toDouble();
}
