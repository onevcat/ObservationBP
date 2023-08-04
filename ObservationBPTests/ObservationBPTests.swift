//
//  ObservationBPTests.swift
//  ObservationBPTests
//
//  Created by Wei Wang on 2023/08/04.
//

import XCTest
import ObservationBP

@usableFromInline
@inline(never)
func _blackHole<T>(_ value: T) { }

@Observable
class ContainsNothing { }

@Observable
class ContainsWeak {
  weak var obj: AnyObject? = nil
}

@Observable
public class PublicContainsWeak {
  public weak var obj: AnyObject? = nil
}

@Observable
class ContainsUnowned {
  unowned var obj: AnyObject? = nil
}

@Observable
class ContainsIUO {
  var obj: Int! = nil
}

class NonObservable {

}

@Observable
class InheritsFromNonObservable: NonObservable {

}

protocol NonObservableProtocol {

}

@Observable
class ConformsToNonObservableProtocol: NonObservableProtocol {

}

struct NonObservableContainer {
  @Observable
  class ObservableContents {
    var field: Int = 3
  }
}

@Observable
final class SendableClass: Sendable {
  var field: Int = 3
}

@Observable
class CodableClass: Codable {
  var field: Int = 3
}

@Observable
final class HashableClass {
  var field: Int = 3
}

extension HashableClass: Hashable {
  static func == (lhs: HashableClass, rhs: HashableClass) -> Bool {
    lhs.field == rhs.field
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(field)
  }
}

@Observable
class ImplementsAccessAndMutation {
  var field = 3
  let accessCalled: (PartialKeyPath<ImplementsAccessAndMutation>) -> Void
  let withMutationCalled: (PartialKeyPath<ImplementsAccessAndMutation>) -> Void

  init(accessCalled: @escaping (PartialKeyPath<ImplementsAccessAndMutation>) -> Void, withMutationCalled: @escaping (PartialKeyPath<ImplementsAccessAndMutation>) -> Void) {
    self.accessCalled = accessCalled
    self.withMutationCalled = withMutationCalled
  }

  internal func access<Member>(
      keyPath: KeyPath<ImplementsAccessAndMutation , Member>
  ) {
    accessCalled(keyPath)
    _$observationRegistrar.access(self, keyPath: keyPath)
  }

  internal func withMutation<Member, T>(
    keyPath: KeyPath<ImplementsAccessAndMutation , Member>,
    _ mutation: () throws -> T
  ) rethrows -> T {
    withMutationCalled(keyPath)
    return try _$observationRegistrar.withMutation(of: self, keyPath: keyPath, mutation)
  }
}

@Observable
class HasIgnoredProperty {
  var field = 3
  @ObservationIgnored var ignored = 4
}

@Observable
class Entity {
  var age: Int = 0
}

@Observable
class Person : Entity {
  var firstName = ""
  var lastName = ""

  var friends = [Person]()

  var fullName: String { firstName + " " + lastName }
}

@Observable
class MiddleNamePerson: Person {
  var middleName = ""

  override var fullName: String { firstName + " " + middleName + " " + lastName }
}

@Observable
class IsolatedClass {
  @MainActor var test = "hello"
}

@MainActor
@Observable
class IsolatedInstance {
  var test = "hello"
}

@Observable
class ClassHasExistingConformance: Observable { }

protocol Intermediary: Observable { }

@Observable
class HasIntermediaryConformance: Intermediary { }

class CapturedState<State>: @unchecked Sendable {
  var state: State

  init(state: State) {
    self.state = state
  }
}

@Observable
class RecursiveInner {
  var value = "prefix"
}

@Observable
class RecursiveOuter {
  var inner = RecursiveInner()
  var value = "prefix"
  @ObservationIgnored var innerEventCount = 0
  @ObservationIgnored var outerEventCount = 0

  func recursiveTrackingCalls() {
    withObservationTracking({
      let _ = value
      _ = withObservationTracking({
        inner.value
      }, onChange: {
        self.innerEventCount += 1
      })
    }, onChange: {
      self.outerEventCount += 1
    })
  }
}


final class ObservationBPTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

}
