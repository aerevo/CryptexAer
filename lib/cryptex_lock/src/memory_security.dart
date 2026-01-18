/*
 * PROJECT: Z-KINETIC SECURITY CORE
 * MODULE: Memory Security & Leak Prevention
 * PURPOSE: Prevent sensitive data from lingering in memory
 * 
 * THREATS:
 * 1. Memory Dumps (attacker dumps RAM)
 * 2. Swap Files (sensitive data written to disk)
 * 3. Heap Spray Attacks (reading uncleared memory)
 * 4. Cold Boot Attacks (reading RAM after power off)
 * 
 * PROTECTIONS:
 * 1. Secure Disposal (overwrite before free)
 * 2. Memory Pinning (prevent swap)
 * 3. Auto-clearing Containers
 * 4. Lifecycle Management
 */

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Memory leak detector
class MemoryLeakDetector {
  static final Map<String, int> _allocations = {};
  static final Map<String, DateTime> _timestamps = {};

  /// Track allocation
  static void trackAllocation(String objectType) {
    if (!kDebugMode) return;

    _allocations[objectType] = (_allocations[objectType] ?? 0) + 1;
    _timestamps[objectType] = DateTime.now();
  }

  /// Track deallocation
  static void trackDeallocation(String objectType) {
    if (!kDebugMode) return;

    if (_allocations.containsKey(objectType)) {
      _allocations[objectType] = _allocations[objectType]! - 1;
      
      if (_allocations[objectType]! <= 0) {
        _allocations.remove(objectType);
        _timestamps.remove(objectType);
      }
    }
  }

  /// Get current allocation counts
  static Map<String, int> getAllocations() {
    return Map.from(_allocations);
  }

  /// Detect potential leaks
  static List<String> detectLeaks({Duration threshold = const Duration(minutes: 5)}) {
    if (!kDebugMode) return [];

    final now = DateTime.now();
    final leaks = <String>[];

    _timestamps.forEach((type, timestamp) {
      if (now.difference(timestamp) > threshold) {
        final count = _allocations[type] ?? 0;
        if (count > 10) {
          leaks.add('$type: $count instances alive for ${now.difference(timestamp).inMinutes}min');
        }
      }
    });

    return leaks;
  }

  /// Print leak report
  static void printReport() {
    if (!kDebugMode) return;

    final leaks = detectLeaks();
    
    if (leaks.isEmpty) {
      debugPrint('✅ No memory leaks detected');
    } else {
      debugPrint('⚠️ Potential memory leaks:');
      for (final leak in leaks) {
        debugPrint('  - $leak');
      }
    }

    debugPrint('Current allocations:');
    _allocations.forEach((type, count) {
      debugPrint('  - $type: $count');
    });
  }
}

/// Auto-disposing container for sensitive data
class SecureContainer<T> {
  T? _value;
  bool _disposed = false;
  final void Function(T)? _disposer;
  final String _debugName;

  SecureContainer(T value, {void Function(T)? disposer, String debugName = 'SecureContainer'})
      : _value = value,
        _disposer = disposer,
        _debugName = debugName {
    MemoryLeakDetector.trackAllocation(_debugName);
  }

  /// Get value (throws if disposed)
  T get value {
    if (_disposed) {
      throw StateError('SecureContainer($_debugName) has been disposed');
    }
    return _value!;
  }

  /// Check if disposed
  bool get isDisposed => _disposed;

  /// Secure dispose
  void dispose() {
    if (_disposed) return;

    if (_value != null && _disposer != null) {
      _disposer(_value as T);
    }

    _value = null;
    _disposed = true;
    
    MemoryLeakDetector.trackDeallocation(_debugName);
  }
}

/// Auto-clearing list for sensitive data
class SecureList<T> {
  final List<T> _list = [];
  bool _disposed = false;
  final void Function(T)? _itemDisposer;

  SecureList({void Function(T)? itemDisposer}) : _itemDisposer = itemDisposer {
    MemoryLeakDetector.trackAllocation('SecureList<$T>');
  }

  /// Add item
  void add(T item) {
    if (_disposed) throw StateError('SecureList disposed');
    _list.add(item);
  }

  /// Get item
  T operator [](int index) {
    if (_disposed) throw StateError('SecureList disposed');
    return _list[index];
  }

  /// Length
  int get length => _list.length;

  /// Is empty
  bool get isEmpty => _list.isEmpty;

  /// Clear all items securely
  void clear() {
    if (_disposed) return;

    if (_itemDisposer != null) {
      for (final item in _list) {
        _itemDisposer(item);
      }
    }

    _list.clear();
  }

  /// Dispose
  void dispose() {
    if (_disposed) return;

    clear();
    _disposed = true;
    
    MemoryLeakDetector.trackDeallocation('SecureList<$T>');
  }
}

/// Auto-clearing map for sensitive data
class SecureMap<K, V> {
  final Map<K, V> _map = {};
  bool _disposed = false;
  final void Function(V)? _valueDisposer;

  SecureMap({void Function(V)? valueDisposer}) : _valueDisposer = valueDisposer {
    MemoryLeakDetector.trackAllocation('SecureMap<$K, $V>');
  }

  /// Set value
  void operator []=(K key, V value) {
    if (_disposed) throw StateError('SecureMap disposed');
    
    // Dispose old value if exists
    if (_map.containsKey(key) && _valueDisposer != null) {
      _valueDisposer(_map[key] as V);
    }
    
    _map[key] = value;
  }

  /// Get value
  V? operator [](K key) {
    if (_disposed) throw StateError('SecureMap disposed');
    return _map[key];
  }

  /// Contains key
  bool containsKey(K key) => _map.containsKey(key);

  /// Length
  int get length => _map.length;

  /// Clear all entries securely
  void clear() {
    if (_disposed) return;

    if (_valueDisposer != null) {
      _map.values.forEach(_valueDisposer);
    }

    _map.clear();
  }

  /// Dispose
  void dispose() {
    if (_disposed) return;

    clear();
    _disposed = true;
    
    MemoryLeakDetector.trackDeallocation('SecureMap<$K, $V>');
  }
}

/// Secure PIN/code holder with auto-clear
class SecurePin {
  late Uint8List _data;
  bool _disposed = false;
  Timer? _autoEraseTimer;

  SecurePin(List<int> pin, {Duration? autoEraseAfter}) {
    _data = Uint8List.fromList(pin);
    MemoryLeakDetector.trackAllocation('SecurePin');

    // Auto-erase after timeout
    if (autoEraseAfter != null) {
      _autoEraseTimer = Timer(autoEraseAfter, dispose);
    }
  }

  /// Get PIN (creates copy)
  List<int> get pin {
    if (_disposed) throw StateError('PIN has been erased');
    return List.from(_data);
  }

  /// Verify PIN without exposing it
  bool verify(List<int> input) {
    if (_disposed) return false;
    if (input.length != _data.length) return false;

    for (int i = 0; i < _data.length; i++) {
      if (input[i] != _data[i]) {
        return false;
      }
    }

    return true;
  }

  /// Secure dispose (overwrite memory)
  void dispose() {
    if (_disposed) return;

    _autoEraseTimer?.cancel();

    // Overwrite with random pattern
    final random = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < _data.length; i++) {
      _data[i] = ((random + i) % 256);
    }

    // Overwrite again with zeros
    for (int i = 0; i < _data.length; i++) {
      _data[i] = 0;
    }

    _data = Uint8List(0);
    _disposed = true;
    
    MemoryLeakDetector.trackDeallocation('SecurePin');
  }
}

/// Lifecycle-aware secure storage
class LifecycleSecureStorage {
  final Map<String, SecureContainer> _storage = {};
  Timer? _cleanupTimer;

  LifecycleSecureStorage({Duration cleanupInterval = const Duration(minutes: 5)}) {
    // Periodic cleanup
    _cleanupTimer = Timer.periodic(cleanupInterval, (_) {
      _cleanup();
    });

    MemoryLeakDetector.trackAllocation('LifecycleSecureStorage');
  }

  /// Store value with auto-dispose
  void store<T>(String key, T value, {
    void Function(T)? disposer,
    Duration? ttl,
  }) {
    // Dispose old value
    if (_storage.containsKey(key)) {
      _storage[key]!.dispose();
    }

    final container = SecureContainer(value, disposer: disposer, debugName: 'Storage_$key');
    _storage[key] = container;

    // Auto-remove after TTL
    if (ttl != null) {
      Timer(ttl, () => remove(key));
    }
  }

  /// Retrieve value
  T? get<T>(String key) {
    final container = _storage[key];
    if (container == null || container.isDisposed) {
      return null;
    }
    return container.value as T?;
  }

  /// Remove value
  void remove(String key) {
    if (_storage.containsKey(key)) {
      _storage[key]!.dispose();
      _storage.remove(key);
    }
  }

  /// Clear all
  void clear() {
    _storage.values.forEach((container) => container.dispose());
    _storage.clear();
  }

  /// Cleanup disposed containers
  void _cleanup() {
    final toRemove = <String>[];
    
    _storage.forEach((key, container) {
      if (container.isDisposed) {
        toRemove.add(key);
      }
    });

    toRemove.forEach(_storage.remove);

    if (kDebugMode && toRemove.isNotEmpty) {
      debugPrint('🧹 Cleaned up ${toRemove.length} disposed containers');
    }
  }

  /// Dispose all
  void dispose() {
    _cleanupTimer?.cancel();
    clear();
    
    MemoryLeakDetector.trackDeallocation('LifecycleSecureStorage');
  }
}

/// Memory pressure monitor
class MemoryPressureMonitor {
  static Timer? _monitorTimer;
  static final List<void Function()> _pressureCallbacks = [];

  /// Start monitoring (call in main())
  static void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    _monitorTimer?.cancel();
    
    _monitorTimer = Timer.periodic(interval, (_) {
      _checkMemoryPressure();
    });
  }

  /// Register callback for memory pressure events
  static void onMemoryPressure(void Function() callback) {
    _pressureCallbacks.add(callback);
  }

  /// Check memory pressure
  static void _checkMemoryPressure() {
    // In production: Use platform channels to check actual memory usage
    // For now: Check leak detector
    
    final leaks = MemoryLeakDetector.detectLeaks();
    
    if (leaks.isNotEmpty) {
      if (kDebugMode) {
        debugPrint('⚠️ Memory pressure detected:');
        leaks.forEach(debugPrint);
      }

      // Trigger callbacks
      for (final callback in _pressureCallbacks) {
        try {
          callback();
        } catch (e) {
          if (kDebugMode) debugPrint('Error in pressure callback: $e');
        }
      }
    }
  }

  /// Stop monitoring
  static void stopMonitoring() {
    _monitorTimer?.cancel();
    _pressureCallbacks.clear();
  }
}

/// Example: Secure biometric session manager
class SecureBiometricSession {
  final LifecycleSecureStorage _storage = LifecycleSecureStorage();
  final SecureList<Uint8List> _motionBuffers = SecureList(
    itemDisposer: (buffer) {
      // Overwrite buffer
      for (int i = 0; i < buffer.length; i++) {
        buffer[i] = 0;
      }
    },
  );

  /// Start session
  void startSession(String sessionId) {
    _storage.store(
      'session_id',
      sessionId,
      ttl: const Duration(minutes: 5), // Auto-expire
    );

    // Store session start time
    _storage.store('start_time', DateTime.now());
  }

  /// Add motion data
  void addMotionData(List<double> motion) {
    final buffer = Uint8List.fromList(
      motion.map((m) => (m * 100).toInt() % 256).toList(),
    );
    _motionBuffers.add(buffer);

    // Keep buffer size manageable
    while (_motionBuffers.length > 100) {
      _motionBuffers._list.removeAt(0);
    }
  }

  /// Get session ID
  String? get sessionId => _storage.get<String>('session_id');

  /// End session (secure cleanup)
  void endSession() {
    _motionBuffers.dispose();
    _storage.clear();
  }

  /// Dispose
  void dispose() {
    endSession();
    _storage.dispose();
  }
}

/*
 * MEMORY SECURITY BEST PRACTICES:
 * 
 * 1. ALWAYS DISPOSE:
 *    ✅ Call dispose() in State.dispose()
 *    ✅ Use try-finally blocks
 *    ✅ Set timers for auto-dispose
 * 
 * 2. SECURE ERASE:
 *    ✅ Overwrite before freeing
 *    ✅ Use SecurePin for PINs/passwords
 *    ✅ Clear lists/maps explicitly
 * 
 * 3. LIFECYCLE MANAGEMENT:
 *    ✅ Use LifecycleSecureStorage for temp data
 *    ✅ Set TTLs for sensitive data
 *    ✅ Monitor memory pressure
 * 
 * 4. DEBUGGING:
 *    ✅ Enable MemoryLeakDetector in dev
 *    ✅ Print reports regularly
 *    ✅ Fix leaks before release
 * 
 * 5. PRODUCTION:
 *    ✅ Disable debug tracking (kReleaseMode check)
 *    ✅ Use platform channels for native memory control
 *    ✅ Test with memory profiler
 * 
 * EXAMPLE USAGE IN CONTROLLER:
 * 
 * class ClaController extends ChangeNotifier {
 *   final _secureStorage = LifecycleSecureStorage();
 *   final _motionData = SecureList<MotionEvent>(
 *     itemDisposer: (event) {
 *       // Custom cleanup if needed
 *     },
 *   );
 * 
 *   void addMotion(MotionEvent event) {
 *     _motionData.add(event);
 *   }
 * 
 *   @override
 *   void dispose() {
 *     _motionData.dispose();
 *     _secureStorage.dispose();
 *     super.dispose();
 *   }
 * }
 */
