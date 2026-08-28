import 'package:test/test.dart';
import 'package:cancellable/cancellable.dart';
import 'package:an_reactive_state/an_reactive_state.dart';

void main() {
  group('RState Extensions', () {
    late Cancellable scope;

    setUp(() {
      scope = Cancellable();
    });

    tearDown(() {
      scope.cancel();
    });

    test('num extensions', () {
      final counter = RState<int>(initialValue: 0, cancellable: scope);
      counter.increment();
      expect(counter.value, 1);
      counter.increment(5);
      expect(counter.value, 6);
      counter.decrement();
      expect(counter.value, 5);
      counter.decrement(2);
      expect(counter.value, 3);
    });

    test('List extensions', () {
      final list = RState<List<int>>(initialValue: [], cancellable: scope);
      int callCount = 0;
      effect(() {
        list.value;
        callCount++;
      }, scope);

      list.add(1);
      expect(list.value, [1]);
      expect(callCount, 2);

      expect(list[0], 1); // operator []

      list[0] = 10; // operator []=
      expect(list.value, [10]);
      expect(callCount, 3);

      list.addAll([2, 3]);
      expect(list.value, [10, 2, 3]);
      expect(callCount, 4);

      list.remove(2);
      expect(list.value, [10, 3]);
      expect(callCount, 5);

      list.clear();
      expect(list.value, []);
      expect(callCount, 6);
    });

    test('Map extensions', () {
      final map = RState<Map<String, int>>(initialValue: {}, cancellable: scope);
      int callCount = 0;
      effect(() {
        map.value;
        callCount++;
      }, scope);

      map['a'] = 1;
      expect(map.value, {'a': 1});
      expect(map['a'], 1); // operator []
      expect(callCount, 2);

      map.remove('a');
      expect(map.value, {});
      expect(callCount, 3);

      map.clear();
      expect(callCount, 3);
    });

    test('ComputedState operators', () {
      final source = RState<List<int>>(initialValue: [1, 2], cancellable: scope);
      final computed = ComputedState<List<int>>(
        cancellable: scope,
        computer: () => source.value.map((e) => e * 2).toList(),
      );

      expect(computed[0], 2);
      expect(computed[1], 4);

      final mapSource = RState<Map<String, int>>(initialValue: {'a': 1}, cancellable: scope);
      final mapComputed = ComputedState<Map<String, int>>(
        cancellable: scope,
        computer: () => mapSource.value,
      );
      expect(mapComputed['a'], 1);
    });

    test('mutate extension', () {
      final list = RState<List<int>>(initialValue: [1], cancellable: scope);
      int callCount = 0;
      effect(() {
        list.value;
        callCount++;
      }, scope);

      list.mutate((l) => l.add(2));
      expect(list.value, [1, 2]);
      expect(callCount, 2);
    });

    test('Set extensions', () {
      final set = RState<Set<int>>(initialValue: {1}, cancellable: scope);
      set.add(2);
      expect(set.value, {1, 2});
      set.remove(1);
      expect(set.value, {2});
    });
  });
}
