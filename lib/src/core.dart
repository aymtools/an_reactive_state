import 'dart:async';

import 'package:cancellable/cancellable.dart';

// ==================== 1. 核心契约与链表上下文 ====================

/// 响应式拓扑网络的基石。
/// 彻底抹去泛型 [T]，只专注于依赖的注册、注销与失效扩散。
abstract class _Observable {
  void addListener(void Function() listener, {Cancellable? cancellable});

  void _removeListener(void Function() listener);

  /// 让每个响应式原子都声明“自己作为下游，如何登记上游依赖”的契约
  void _reportDependency(_Observable parentState);
}

/// 链表化环境上下文节点
class _EvaluationContext {
  final _Observable? observable;
  final bool isUntracked;
  final _EvaluationContext? parent;

  _EvaluationContext({
    required this.observable,
    required this.isUntracked,
    required this.parent,
  });
}

/// 统一的响应式环境上下文管理器（Zone 局部存储 + 链表优化版）
class _ReactiveScope {
  static final _ReactiveScope _instance = _ReactiveScope._internal();

  factory _ReactiveScope() => _instance;

  _ReactiveScope._internal();

  // 定义 Zone 专用的私有 Symbol 标识符，防止全局变量跨异步踩踏
  static const Object _contextKey = #_reactive_context_node;
  static const Object _batchDepthKey = #_reactive_batch_depth;

  // 从当前 Zone 环境中安全提取属于该异步调用栈的链表头
  _EvaluationContext? get _currentContext => Zone.current[_contextKey] as _EvaluationContext?;

  int get _batchDepth => (Zone.current[_batchDepthKey] as int?) ?? 0;

  // 批量缓冲区
  final Set<_Observable> _batchQueue = {};

  _Observable? get activeContext => _currentContext?.observable;

  bool get isUntrackedMode => _currentContext?.isUntracked ?? false;

  /// 压栈并切入 Zone：利用 Zone.current.fork 动态创建并切入隔离的异步上下文
  void pushContext(_Observable? observable, bool untracked, void Function() body) {
    final nextNode = _EvaluationContext(
      observable: observable,
      isUntracked: untracked,
      parent: _currentContext, // 链表指针依然指向父级
    );

    // 派生一个新的安全 Zone 区域，将新节点绑定进去，运行结束后自动退栈
    runZoned(body, zoneValues: {
      _contextKey: nextNode,
      _batchDepthKey: _batchDepth,
    });
  }

  bool get isBatching => _batchDepth > 0;

  void queueNotification(_Observable observable) => _batchQueue.add(observable);

  /// 批量作用域控制：通过 runZoned 进行作用域深度递增隔离
  void runInBatch(void Function() action) {
    runZoned(() {
      action();

      // 只有当外层批量逻辑彻底退出（深度归零）后，才同步派发通知
      if (_batchDepth + 1 == 1) {
        final finalObservables = List<_Observable>.from(_batchQueue);
        _batchQueue.clear();
        for (final obs in finalObservables) {
          if (obs is _BaseState) {
            obs._directNotifyListeners();
          }
        }
      }
    }, zoneValues: {
      _contextKey: _currentContext,
      _batchDepthKey: _batchDepth + 1, // 递增批量深度
    });
  }
}

// ==================== 2. 全局便捷函数入口 ====================

/// 批量推迟通知函数糖
void batch(void Function() action) => _ReactiveScope().runInBatch(action);

/// 只取值不监听函数糖
R untracked<R>(R Function() action) {
  final scope = _ReactiveScope();
  R? result;
  scope.pushContext(scope.activeContext, true, () {
    result = action();
  });
  return result as R;
}

// ==================== 3. 终极强悍的 State 体系实现 ====================

abstract class _BaseState<T> implements _Observable {
  T? _cachedValue;
  final Cancellable _rootCancellable;
  final bool Function(T a, T b)? _equals;

  final List<void Function()> _listeners = [];
  bool _isDirty = true;

  final Map<_Observable, Cancellable> _activeParentTokens = {};
  Set<_Observable> _dependencies = {};

  _BaseState({
    required Cancellable cancellable,
    bool Function(T a, T b)? equals,
  })  : _rootCancellable = cancellable,
        _equals = equals {
    _rootCancellable.onCancel.then((_) {
      _listeners.clear();
      _clearAllDependencies();
    });
  }

  void _clearAllDependencies() {
    for (final token in _activeParentTokens.values) {
      token.cancel();
    }
    _activeParentTokens.clear();
    _dependencies.clear();
  }

  T peek() => untracked(() => value);

  T get value {
    if (_isDirty) {
      _evaluateIfDirty();
    }

    final scope = _ReactiveScope();
    if (scope.activeContext != null && !scope.isUntrackedMode) {
      scope.activeContext!._reportDependency(this);
    }
    return _cachedValue as T;
  }

  void _evaluateIfDirty();

  bool _isEqual(T oldVal, T newVal) {
    if (_equals != null) return _equals!(oldVal, newVal);
    return oldVal == newVal;
  }

  @override
  void _reportDependency(_Observable parentState) {
    if (_dependencies.add(parentState)) {
      if (!_activeParentTokens.containsKey(parentState)) {
        final depToken = _rootCancellable.makeCancellable();
        _activeParentTokens[parentState] = depToken;

        void onParentChange() {
          if (!_isDirty) {
            _isDirty = true;
            _notifyOrQueue();
          }
        }

        parentState.addListener(onParentChange);
        depToken.onCancel.then((_) => parentState._removeListener(onParentChange));
      }
    }
  }

  void _notifyOrQueue() {
    final scope = _ReactiveScope();
    if (scope.isBatching) {
      scope.queueNotification(this);
    } else {
      _directNotifyListeners();
    }
  }

  void _directNotifyListeners() {
    final targets = List<void Function()>.from(_listeners);
    for (final listener in targets) {
      listener();
    }
  }

  @override
  void addListener(void Function() listener, {Cancellable? cancellable}) {
    if (!_rootCancellable.isAvailable) return;
    if (cancellable != null && !cancellable.isAvailable) return;

    _listeners.add(listener);

    if (cancellable != null) {
      cancellable.onCancel.then((_) => _removeListener(listener));
    }
  }

  @override
  void _removeListener(void Function() listener) {
    _listeners.remove(listener);
  }
}

class RState<T> extends _BaseState<T> {
  RState({
    required T initialValue,
    required super.cancellable,
    super.equals,
  }) {
    _cachedValue = initialValue;
    _isDirty = false;
  }

  @override
  void _evaluateIfDirty() {
    // RState as a source manages its own state, nothing to evaluate here.
  }

  set value(T newValue) {
    if (!_rootCancellable.isAvailable) return;
    if (_isEqual(_cachedValue as T, newValue)) return;

    _cachedValue = newValue;
    _notifyOrQueue();
  }

  /// 强制通知下游进行刷新
  void refresh() {
    _notifyOrQueue();
  }
}

class ComputedState<T> extends _BaseState<T> {
  final T Function() _computer;

  ComputedState({
    required T Function() computer,
    required super.cancellable,
    super.equals,
  }) : _computer = computer;

  @override
  void _evaluateIfDirty() {
    _evaluateAndTrack();
  }

  void _evaluateAndTrack() {
    if (!_rootCancellable.isAvailable) return;

    final scope = _ReactiveScope();

    // 循环依赖检测：自底向上遍历 Zone 内部留存的环境链表，确保无死循环
    _EvaluationContext? ancestor = scope._currentContext;
    while (ancestor != null) {
      if (ancestor.observable == this) {
        throw StateError('【拓扑崩溃】检测到循环依赖死循环！');
      }
      ancestor = ancestor.parent;
    }

    final oldDependencies = _dependencies;
    final newDependencies = <_Observable>{};
    _dependencies = newDependencies;

    // 将自己压入全新隔离的 Zone 上下文中安全求值，彻底无需手动执行 pop()
    scope.pushContext(this, false, () {
      late T freshValue;
      bool hasError = false;

      try {
        freshValue = _computer();
      } catch (e) {
        hasError = true;
        // 如果是首次求值失败且没有旧值，可能会抛出异常，这里保持现状
        if (_cachedValue != null) {
          freshValue = _cachedValue as T;
        } else {
          rethrow;
        }
      }

      // 精确依赖 Diff：只切断不再被选中的逻辑分支对应的上游监听
      for (final oldParent in oldDependencies) {
        if (!newDependencies.contains(oldParent)) {
          final tokenToRemove = _activeParentTokens.remove(oldParent);
          tokenToRemove?.cancel();
        }
      }

      _isDirty = false;

      // 结合 Equality Guard 判定最终结果是否存在实质演变
      if (!hasError && (_cachedValue == null || !_isEqual(_cachedValue as T, freshValue))) {
        _cachedValue = freshValue;
        _notifyOrQueue();
      }
    });
  }
}

/// 全局副作用注册器，用于自动运行和追踪一个无返回值操作（完全适配 Zone 链表架构）
class _EffectInstance implements _Observable {
  final void Function() _action;
  final Cancellable _token;
  Set<_Observable> _dependencies = {};
  final Map<_Observable, Cancellable> _parentTokens = {};

  _EffectInstance(this._action, this._token) {
    _token.onCancel.then((_) {
      for (final t in _parentTokens.values) {
        t.cancel();
      }
      _parentTokens.clear();
      _dependencies.clear();
    });
    run();
  }

  void run() {
    if (!_token.isAvailable) return;

    // 1. 备份旧依赖，初始化新一轮收集箱
    final oldDeps = _dependencies;
    final newDeps = <_Observable>{};
    _dependencies = newDeps;

    final scope = _ReactiveScope();

    // 2. 核心改动：使用全新隔离的 Zone 闭包运行它！
    // 运行结束后，该 Effect 上下文会被全自动安全弹出，无需手动调用 pop，完美防踩踏
    scope.pushContext(this, false, () {
      try {
        _action(); // 执行副作用操作，自动激发上游 State 的 _reportDependency
      } catch (e) {
        // print('【异常隔离】Effect 闭包执行抛出异常，拓扑拦截。错误原因: $e');
      }
    });

    // 3. 动态依赖精确 Diff 优化
    for (final oldParent in oldDeps) {
      if (!newDeps.contains(oldParent)) {
        _parentTokens.remove(oldParent)?.cancel();
      }
    }
  }

  @override
  void _reportDependency(_Observable parentState) {
    if (_dependencies.add(parentState)) {
      if (!_parentTokens.containsKey(parentState)) {
        final depToken = _token.makeCancellable();
        _parentTokens[parentState] = depToken;

        // 当上游依赖的值在未来发生真正的演变时，强同步重新跑整个 Effect 闭包
        void onParentChange() => run();

        parentState.addListener(onParentChange);
        depToken.onCancel.then((_) => parentState._removeListener(onParentChange));
      }
    }
  }

  // Effect 属于依赖图的终端（叶子节点），不会再有更下游去读它，因此 add/remove 为空实现
  @override
  void addListener(void Function() listener, {Cancellable? cancellable}) {}

  @override
  void _removeListener(void Function() listener) {}
}

// ==================== 4. 全局顶层副作用函数糖 ====================

/// 全自动响应式副作用处理器。
/// 传入的 [action] 会立刻执行一次，并且未来内部读取的任何 State 变更时都会强同步自动重跑。
void effect(void Function() action, Cancellable cancellable) {
  _EffectInstance(action, cancellable);
}
