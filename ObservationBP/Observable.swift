//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//


/// A type that emits notifications to observers when underlying data changes.
///
/// Conforming to this protocol signals to other APIs that the type supports
/// observation. However, applying the `Observable` protocol by itself to a
/// type doesn't add observation functionality to the type. Instead, always use
/// the ``Observation/Observable()`` macro when adding observation
/// support to a type.
public protocol Observable { }

#if $Macros && hasAttribute(attached)

/// Defines and implements conformance of the Observable protocol.
///
/// This macro adds observation support to a custom type and conforms the type
/// to the ``Observation/Observable`` protocol. For example, the following code
/// applies the `Observable` macro to the type `Car` making it observable:
///
///     @Observable
///     class Car {
///        var name: String = ""
///        var needsRepairs: Bool = false
///
///        init(name: String, needsRepairs: Bool = false) {
///            self.name = name
///            self.needsRepairs = needsRepairs
///        }
///     }
@attached(member, names: named(_$observationRegistrar), named(access), named(withMutation))
@attached(memberAttribute)
@attached(`extension`, conformances: Observable)
public macro Observable() =
  #externalMacro(module: "ObservationBPMacrosMacros", type: "ObservableMacro")

/// Synthesizes a property for accessors.
///
/// The ``Observation`` module uses this macro. Its use outside of the
/// framework isn't necessary.
@attached(accessor, names: named(init), named(get), named(set))
@attached(peer, names: prefixed(_))
public macro ObservationTracked() =
  #externalMacro(module: "ObservationBPMacrosMacros", type: "ObservationTrackedMacro")

/// Disables observation tracking of a property.
///
/// By default, an object can observe any property of an observable type that
/// is accessible to the observing object. To prevent observation of an
/// accessible property, attach the `ObservationIgnored` macro to the property.
@attached(accessor, names: named(willSet))
public macro ObservationIgnored() =
  #externalMacro(module: "ObservationBPMacrosMacros", type: "ObservationIgnoredMacro")

#endif
