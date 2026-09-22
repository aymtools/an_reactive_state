## 1.2.1

* **API**: Added `makeLiveCancellable()` to `_Observable` and its implementations (`BaseState`, `_EffectInstance`) for custom `Cancellable` binding with weak reference support.
* **Internal**: Refactored `disposable` property to delegate to `makeLiveCancellable(weakRef: false)`.

## 1.2.0

* **API**: Made `cancellable` parameter optional in `BaseState`, `RState`, and `ComputedState`.

### Breaking Change

* Changed `effect()` second argument `cancellable` from positional required to named optional (
  `effect(action, {cancellable})`).

## 1.1.0

* **Architecture**: Refactored `RState` to inherit from `ComputedState` for unified reactive logic.
* **Features**: Added `mutate()`, `refresh()`, and comprehensive extensions for `num`, `bool`, and
  collections (`List`, `Set`, `Map`).
* **Stability**: Improved nullable type support and optimized the batch notification engine.
* **API**: Added `Cancellable` support to `addListener` and implemented collection index operators (
  `[]`, `[]=`).

## 1.0.0

* First version release
