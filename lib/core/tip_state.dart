import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tips.dart';

/// Состояние подсказок: какие уже закрыты и какую по счёту показывать
/// на конкретном экране. Живёт в памяти сеанса — навязчивых «больше не
/// показывать» между запусками не обещаем.
class TipState {
  final Set<String> dismissed;
  final Map<TipScreen, int> offset;

  const TipState({this.dismissed = const {}, this.offset = const {}});

  TipState copyWith({Set<String>? dismissed, Map<TipScreen, int>? offset}) =>
      TipState(
        dismissed: dismissed ?? this.dismissed,
        offset: offset ?? this.offset,
      );
}

class TipNotifier extends Notifier<TipState> {
  @override
  TipState build() => const TipState();

  void dismiss(String id) {
    state = state.copyWith(dismissed: {...state.dismissed, id});
  }

  void next(TipScreen screen, int count) {
    if (count <= 0) return;
    final current = state.offset[screen] ?? 0;
    state = state.copyWith(
      offset: {...state.offset, screen: (current + 1) % count},
    );
  }
}

final tipStateProvider =
    NotifierProvider<TipNotifier, TipState>(TipNotifier.new);
