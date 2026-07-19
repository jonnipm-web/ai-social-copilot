import 'package:flutter/foundation.dart';

/// Estado visual global da IVE. Mantém o launcher externo fora de chats,
/// dialogs e bottom sheets sem acoplar o Navigator ao Riverpod.
class IvePresentationController extends ChangeNotifier {
  bool _chatOpen = false;
  final Set<Object> _modalRoutes = <Object>{};

  bool get chatOpen => _chatOpen;
  bool get hasModal => _modalRoutes.isNotEmpty;
  bool get externalOverlayVisible => !_chatOpen && !hasModal;

  void setChatOpen(bool value) {
    if (_chatOpen == value) return;
    _chatOpen = value;
    notifyListeners();
  }

  void registerModal(Object route) {
    if (_modalRoutes.add(route)) notifyListeners();
  }

  void unregisterModal(Object route) {
    if (_modalRoutes.remove(route)) notifyListeners();
  }

  void reset() {
    _chatOpen = false;
    _modalRoutes.clear();
    notifyListeners();
  }
}

final ivePresentationController = IvePresentationController();
