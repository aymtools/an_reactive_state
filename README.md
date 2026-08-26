# an_reactive_state

An industrial-grade, call-stack synchronous reactive graph engine (Signals) for pure Dart and
Flutter, built for ultimate evaluation performance and absolute memory safety.

`an_reactive_state` discards the heavy macro-task/micro-task scheduling overhead found in
traditional asynchronous stream models (such as Stream or Kotlin Flow). Instead, it runs entirely on
an ultra-fast **CPU Call-Stack synchronous reactive topology**. Deeply integrated with the
`Cancellable` lifecycle tree, it fundamentally eliminates async context interleaving bugs and memory
leaks.

---

## 🌟 Key Killer Features

* ⚡ **Unified Evaluation Model**: Combines `MutableState` and `ComputedState` into a single,
  cohesive `RState<T>` class driven by an authoritative internal `_computer`. It is entirely
  polymorphic-transparent and supports infinite dependency chain nesting (A -> B -> C -> D).
* ⛓️ **Linked-List Evaluation Context**: Replaces expensive dynamic array reallocations with a
  lightweight, doubly-linked-list node switching architecture. PUSH/POP operations for reactive
  tracking run at a strict, deterministic **O(1) time complexity**.
* 🛡️ **Zone-Safe Async Isolation**: Leverages Dart's native `Zone` local storage mechanism. When
  multiple asynchronous tasks interleave and modify states concurrently, the dependency tracking and
  evaluation scope remain strictly isolated per execution branch, preventing global state pollution.
* 🛑 **Zero-Leak Lifecycle Self-Destruction**: Fully bound to the `Cancellable` token tree. When a
  host container is disposed of, all parent-child listener registrations are permanently purged
  within a single atomic microsecond, leaving zero memory overhead.
* 🚫 **Circular Dependency Watchdog**: Before entering the call-stack evaluation domain, it crawls
  upwards from the current node to check its ancestors. If a dependency loop is detected, it throws
  a transparent `StateError` immediately, eliminating any risk of Stack Overflow crashes.
* 🔍 **Lazy Evaluation & Memoization**: Implements a highly efficient "Dirty Propagation" mechanism.
  Derived computation states do not calculate values eagerly upon initialization. They run only when
  a downstream node or listener explicitly invokes `get value` or `addListener`, caching the output
  until upstreams flag it as dirty again.
* ⚖️ **Equality Guard**: Supports custom equality comparers. Even if your calculation closure
  generates a brand-new instance (such as a fresh `List` or object mapping), it will block
  downstream propagation if the content remains identical, completely terminating downstream
  evaluation ripples.
* 📦 **Synchronous Batching & Untracking**: Provides global `batch` and `untracked` closures. You can
  execute multiple rapid updates inside a `batch` block while ensuring downstream effects are
  triggered **exactly once**, executing synchronously right before exiting the block—with no
  microtask latency.

---

## 📦 Installation

Add the following dependencies to your `pubspec.yaml`:

```yaml
dependencies:
  an_reactive_state: ^1.0.0
  cancellable: ^2.6.0     # The foundation of industrial lifecycle management
```

---

## 🚀 Core Usage Guide

### 1. Basic Read/Write, Derived State, and Side Effects (`effect`)

In `an_reactive_state`, raw state sources and high-order calculation pipelines share a uniform
interface under `State<T>`.

```dart
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
    getter: () => price.value * count.value, // Automatically tracks price and count
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
```

### 2. Postponing Notifications (`batch`) & Reading Without Tracking (`untracked`)

Wrap multiple independent value adjustments inside a `batch` to prevent computational jitter. Use
`untracked` to pull snapshots of data safely without contaminating the active evaluation graph.

```dart
void main() {
  final scope = Cancellable();

  final width = RState<int>(initialValue: 10, cancellable: scope);
  final height = RState<int>(initialValue: 5, cancellable: scope);
  final isLogging = RState<bool>(initialValue: true, cancellable: scope);

  final areaReport = RState<String>(
    cancellable: scope,
    computer: () {
      // Core control: Read the switch silently inside an untracked closure.
      // This ensures areaReport does NOT establish a dependency on isLogging!
      final logActive = untracked(() => isLogging.value);
      if (logActive) {
        untracked(() => print('【System Internal】Evaluating reactive matrix area...'));
      }
      return 'Current Area: \${width.value * height.value} sq.m';
    },
  );

  areaReport.addListener(() => print('【External Screen】Updated -> \${areaReport.value}'));

  print('\n--- Scenario: Triggering Batch Updates ---');
  batch(() {
    print('(Starting sequential assignments inside batch...)');
    width.value = 20; // Upstream flags change, downstream evaluation holds
    height.value = 10; // Upstream flags change, downstream evaluation holds
    print('(Exiting batch scope shortly)');
  });
  // Downstream triggers EXACTLY ONCE on the call-stack right at the block exit!

  scope.cancel();
}
```

---

## 🏗️ Domain Lifecycle Management

In true production-grade architectures, wrapping your reactive states inside a manageable domain
controller gives you a clean state tree with absolute memory safety.

```dart
import 'package:cancellable/cancellable.dart';
import 'package:an_reactive_state/an_reactive_state.dart';

class OrderCartManager {
  // Establish a single master cancellable token for this business module
  final Cancellable _bag = Cancellable();

  late final RState<double> productPrice;
  late final RState<int> quantity;
  late final RState<double> finalPay;

  OrderCartManager() {
    productPrice = RState<double>(initialValue: 15.0, cancellable: _bag);
    quantity = RState<int>(initialValue: 1, cancellable: _bag);

    finalPay = RState<double>(
      cancellable: _bag,
      // Inject Equality Guard to ensure content matching blocks computational duplication
      equals: (a, b) => a == b,
      computer: () => productPrice.value * quantity.value,
    );

    // Bind automated domain side-effects
    effect(() {
      print('【Domain Event Report】Current final payment amount flowed to: \${finalPay.value}');
    }, _bag);
  }

  void addItems(int countToAdd) {
    quantity.value += countToAdd;
  }

  // Explicitly wipe bindings completely when this manager clears up
  void dispose() {
    print('【Architecture Lifecycle】Manager is clearing; triggering global state graph flush!');
    _bag.cancel(); // All map registries and closures are cleared in 0μs, guaranteeing 0 leaks.
  }
}
```

---

## 🛠️ Functional Advanced Trick: Freeze / Once Memoization

You do not even need to extend the internal methods of `RState`. Thanks to our highly sensitive *
*Dual-Buffered Graph Diffing algorithm**, a developer can write an self-rewriting closure inside the
`getter` to achieve an auto-detaching one-time snapshot that **calculates only once, breaks all
parent connections, and permanently freezes itself**:

```dart

final RState<String> lazyAndFrozenConfig = RState<String>(
  cancellable: scope,
  computer: () {
    String? snapshot;
    return () {
      if (snapshot != null) {
        // Ensuing access pathways drop into the memoized cache branch.
        // Because no upstreams (like remoteIp.value) are invoked here,
        // our dynamic graph diff engine automatically realizes those parent dependencies 
        // are no longer needed, permanently severing listeners from the parent list!
        return untracked(() => snapshot!);
      }
      print('【Extreme Optimization】Executing heavy configuration parsing exactly once...');
      snapshot = 'Server Endpoint: IP=\${remoteIp.value}, PORT=\${remotePort.value}';
      return snapshot!;
    };
  }(), // Immediately run the outer closure to bind the self-detaching inner function
);
```

---

## Issues

If you encounter issues, here are some tips for debug, if nothing helps report
to [issue tracker on GitHub](https://github.com/aymtools/an_reactive_state/issues):