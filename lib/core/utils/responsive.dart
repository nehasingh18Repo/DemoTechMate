import 'package:flutter/material.dart';

class Responsive {
  Responsive._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 600;

  static double contentMaxWidth(BuildContext context) =>
      isTablet(context) ? 720 : double.infinity;

  static EdgeInsets pagePadding(BuildContext context) =>
      EdgeInsets.symmetric(
        horizontal: isTablet(context) ? 32 : 16,
        vertical: 16,
      );

  static int gridCrossAxisCount(BuildContext context) =>
      isTablet(context) ? 2 : 1;
}
