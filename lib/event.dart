import 'package:flutter/material.dart';

class Event {
  List<(WeakReference<Object>, Function)> _listeners = [];

  void bind(Object owner, Function callback) {
    _listeners.add((WeakReference(owner), callback));
  }

  void emit() {
    for (var (owner, listener) in _listeners) {
      Object? target = owner.target;
      if (target == null) continue;
      if (target is State && !target.mounted) continue;
      listener();
    }
  }
}