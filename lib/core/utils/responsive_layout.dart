import 'package:flutter/widgets.dart';
import 'package:luna_sight/core/constants/app_constants.dart';

/// Screen size categorization for responsive layouts.
enum ScreenDeviceClass { compact, medium, expanded }

/// Breakpoint and responsive layout utility methods.
class ResponsiveLayout {
  ResponsiveLayout._();

  static ScreenDeviceClass getDeviceClass(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < AppConstants.breakpointCompact) {
      return ScreenDeviceClass.compact;
    } else if (width < AppConstants.breakpointMedium) {
      return ScreenDeviceClass.medium;
    } else {
      return ScreenDeviceClass.expanded;
    }
  }

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AppConstants.breakpointCompact;

  static bool isMedium(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= AppConstants.breakpointCompact &&
        width < AppConstants.breakpointMedium;
  }

  static bool isExpanded(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= AppConstants.breakpointMedium;
}
