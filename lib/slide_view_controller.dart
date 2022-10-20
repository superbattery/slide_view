import 'package:flutter/foundation.dart';

class SlideViewController extends ChangeNotifier {
  /// 抽屉的状态
  bool isOpen = false;

  Future<void> change(bool opening) async {
    throw UnimplementedError();
    isOpen = true;
    notifyListeners();
  }
}
