import 'package:cancellable/cancellable.dart';
import 'package:an_reactive_state/an_reactive_state.dart';

void main() {
  final scope = Cancellable();

  // 1. Declare raw state atoms (omitting the getter closure makes it a writable state)
  final price = RState<double>(initialValue: 99.0, cancellable: scope);
  final count = RState<int>(initialValue: 1, cancellable: scope);

  // 2. Declare a high-order derived calculation state driven by an internal getter
  final totalPrice = RState<double>(
    cancellable: scope,
    computer: () => price.value * count.value, // Automatically tracks price and count
  );

  // 3. Register a side effect: whatever reactive states it reads inside the block,
  // it will automatically re-run whenever those states change.
  effect(() {
    print('【UI Effect Card】Current total checkout amount: \${totalPrice.value}');
  }, scope);

  print('--- Modifying Quantity ---');
  count.value = 3; // Executed synchronously inside the current call stack

  scope.cancel(); // Everything self-destructs; subsequent writes are safely blocked.
}