import 'package:flutter/material.dart';

import 'locked_feature_sheet.dart';

extension LockedSheetExtension on BuildContext {
  void showLockedFeatureSheet(String featureName) {
    showModalBottomSheet(
      context: this, // 'this' refers to the BuildContext calling the method
      backgroundColor: Colors.transparent,
      builder: (context) => LockedFeatureSheet(featureName: featureName),
    );
  }
}
