import 'package:flutter/material.dart';

class RiskBadge extends StatelessWidget {
  final String riskCategory; // Green, Yellow, Orange, Red

  const RiskBadge({super.key, required this.riskCategory});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    switch (riskCategory.toLowerCase()) {
      case 'red':
        badgeColor = Colors.red;
        break;
      case 'orange':
        badgeColor = Colors.orange;
        break;
      case 'yellow':
        badgeColor = Colors.amber;
        break;
      case 'green':
      default:
        badgeColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        riskCategory.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
