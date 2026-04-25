import 'package:core/presentation/utils/responsive_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AiScribeMobileUtils {
  static bool isScribeInMobileMode(BuildContext? context) {
    if (context == null) return false;
    final responsiveUtils = Get.find<ResponsiveUtils>();
    return responsiveUtils.isMobile(context) ||
        responsiveUtils.isLandscapeMobile(context);
  }
}
