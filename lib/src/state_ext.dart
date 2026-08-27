import 'core.dart';

/// 通用操作扩展，适用于所有 RState
extension RStateCommonExt<T> on RState<T> {
  /// 通过闭包更新状态（替换模式，受 Equality Guard 保护）
  void update(T Function(T old) updater) {
    value = updater(value);
  }

  /// 原位修改对象并强制刷新（绕过 Equality Guard，适用于大型集合或复杂对象内部修改）
  void mutate(void Function(T val) action) {
    action(value);
    refresh();
  }
}

/// 数字类型快捷操作
extension RStateNumExt<T extends num> on RState<T> {
  /// 自增，step 默认为 1
  void increment([T? step]) => value = (value + (step ?? 1)) as T;

  /// 自减，step 默认为 1
  void decrement([T? step]) => value = (value - (step ?? 1)) as T;
}

/// 布尔类型快捷操作
extension RStateBoolExt on RState<bool> {
  /// 切换布尔值
  void toggle() => value = !value;
}

/// 列表类型快捷操作
extension RStateListExt<T> on RState<List<T>> {
  /// 读取元素（自动建立响应式追踪）
  T operator [](int index) => value[index];

  /// 修改指定位置元素（替换模式，触发拓扑更新）
  void operator []=(int index, T val) =>
      update((l) => List<T>.from(l)..[index] = val);

  /// 添加元素
  void add(T item) => update((l) => List<T>.from(l)..add(item));

  /// 添加多个元素
  void addAll(Iterable<T> items) =>
      update((l) => List<T>.from(l)..addAll(items));

  /// 移除元素
  void remove(T item) => update((l) => List<T>.from(l)..remove(item));

  /// 移除指定位置元素
  void removeAt(int index) => update((l) => List<T>.from(l)..removeAt(index));

  /// 清空列表
  void clear() => value = [];
}

/// Set 类型快捷操作
extension RStateSetExt<T> on RState<Set<T>> {
  /// 添加元素
  void add(T item) => update((s) => Set<T>.from(s)..add(item));

  /// 移除元素
  void remove(T item) => update((s) => Set<T>.from(s)..remove(item));

  /// 清空 Set
  void clear() => value = {};
}

/// Map 类型快捷操作
extension RStateMapExt<K, V> on RState<Map<K, V>> {
  /// 读取键值（自动建立响应式追踪）
  V? operator [](K key) => value[key];

  /// 设置键值对（替换模式，触发拓扑更新）
  void operator []=(K key, V val) =>
      update((m) => Map<K, V>.from(m)..[key] = val);

  /// 移除键
  void remove(K key) => update((m) => Map<K, V>.from(m)..remove(key));

  /// 清空 Map
  void clear() => value = {};
}

/// 计算状态的列表读取扩展
extension ComputedStateListExt<T> on ComputedState<List<T>> {
  /// 读取元素（自动建立响应式追踪）
  T operator [](int index) => value[index];
}

/// 计算状态的 Map 读取扩展
extension ComputedStateMapExt<K, V> on ComputedState<Map<K, V>> {
  /// 读取键值（自动建立响应式追踪）
  V? operator [](K key) => value[key];
}
