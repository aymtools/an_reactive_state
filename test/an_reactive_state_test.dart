import 'package:test/test.dart';
import 'package:cancellable/cancellable.dart';
import 'package:an_reactive_state/an_reactive_state.dart';

void main() {
  group('Refactor Verification', () {
    late Cancellable scope;

    setUp(() {
      scope = Cancellable();
    });

    tearDown(() {
      scope.cancel();
    });

    test('RState and ComputedState basic interaction', () {
      final a = RState<int>(initialValue: 1, cancellable: scope);
      final b = RState<int>(initialValue: 2, cancellable: scope);
      final sum = ComputedState<int>(
        cancellable: scope,
        computer: () => a.value + b.value,
      );

      int effectCount = 0;
      int? lastSum;
      effect(() {
        effectCount++;
        lastSum = sum.value;
      }, scope);

      expect(lastSum, 3);
      expect(effectCount, 1);

      a.value = 10;
      expect(lastSum, 12);
      expect(effectCount, 2);

      batch(() {
        a.value = 20;
        b.value = 30;
      });
      expect(lastSum, 50);
      expect(effectCount, 3);
    });

    test('Recursive dependency detection', () {
      late ComputedState<int> a;
      a = ComputedState<int>(
        cancellable: scope,
        computer: () => a.value + 1,
      );

      expect(() => a.value, throwsStateError);
    });

    test('addListener with auto-cancellation', () {
      final state = RState<int>(initialValue: 0, cancellable: scope);
      final listenerScope = Cancellable();
      int callCount = 0;

      state.addListener(() {
        callCount++;
      }, cancellable: listenerScope);

      state.value = 1;
      expect(callCount, 1);

      listenerScope.cancel();
      state.value = 2;
      expect(callCount, 1); // Should not increase
    });

    test('RState refresh forces notification', () {
      final state = RState<int>(initialValue: 10, cancellable: scope);
      int callCount = 0;
      effect(() {
        state.value;
        callCount++;
      }, scope);

      expect(callCount, 1);
      state.refresh();
      expect(callCount, 2);
    });
  });
}
