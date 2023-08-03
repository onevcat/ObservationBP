//
//  ThreadLocal.swift
//  MyObservation
//
//  Created by Wei Wang on 2023/08/03.
//

@_silgen_name("_swift_observation_tls_get")
func _tlsGet() -> UnsafeMutableRawPointer?

@_silgen_name("_swift_observation_tls_set")
func _tlsSet(_ value: UnsafeMutableRawPointer?)

struct _ThreadLocal {
  static var value: UnsafeMutableRawPointer? {
    get {
      return _tlsGet()
    }
    set {
      _tlsSet(newValue)
    }
  }
}
