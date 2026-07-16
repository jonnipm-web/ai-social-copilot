import 'dart:async';

import '../../data/models/ive_event.dart';

/// Bus global de eventos da IVE™.
/// Serviços emitem — IveNotifier consome e reage com mensagens/expressões.
class IveEventBus {
  IveEventBus._();

  static final IveEventBus instance = IveEventBus._();

  final _controller = StreamController<IveEvent>.broadcast();

  Stream<IveEvent> get stream => _controller.stream;

  void emit(IveEvent event) {
    if (!_controller.isClosed) _controller.add(event);
  }
}
