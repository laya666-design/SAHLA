import 'package:flutter/material.dart';
import '../services/ocr_service.dart';
import '../theme/app_theme.dart';

class StatusCard extends StatelessWidget {
  final ExpiryStatus status;

  const StatusCard({super.key, required this.status});

  Color get _bgColor {
    switch (status.level) {
      case StatusLevel.ok:
        return AppColors.successLight;
      case StatusLevel.warning:
        return AppColors.warningLight;
      case StatusLevel.expired:
        return AppColors.errorLight;
    }
  }

  Color get _fgColor {
    switch (status.level) {
      case StatusLevel.ok:
        return AppColors.success;
      case StatusLevel.warning:
        return AppColors.warning;
      case StatusLevel.expired:
        return AppColors.errorText;
    }
  }

  IconData get _icon {
    switch (status.level) {
      case StatusLevel.ok:
        return Icons.check_circle_rounded;
      case StatusLevel.warning:
        return Icons.warning_amber_rounded;
      case StatusLevel.expired:
        return Icons.error_rounded;
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon, color: _fgColor, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'Expiration : ${_fmt(status.expirationDate)}',
                style: TextStyle(
                  color: _fgColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status.label,
            style: TextStyle(
              color: _fgColor,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}
