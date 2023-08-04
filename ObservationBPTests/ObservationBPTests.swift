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
    func testOnlyInstantiate() throws {
        let test = MiddleNamePerson()
    }
    
    
    func testUnobservedValueChanges() throws {
      let test = MiddleNamePerson()
      for i in 0..<100 {
        test.firstName = "\(i)"
      }
    }
    
    func testTrackingChanges() throws {
      let changed = CapturedState(state: false)
      
      let test = MiddleNamePerson()
      withObservationTracking {
        _blackHole(test.firstName)
      } onChange: {
        changed.state = true
      }
      
      test.firstName = "c"
      XCTAssertEqual(changed.state, true)
      changed.state = false
      test.firstName = "c"
      XCTAssertEqual(changed.state, false)
    }

    func testConformance() throws {
      func testConformance<O: Observable>(_ o: O) -> Bool {
        return true
      }
      
      func testConformance<O>(_ o: O) -> Bool {
        return false
      }
      
      let test = Person()
      XCTAssertEqual(testConformance(test), true)
    }
    
    func testTrackingNonChanged() throws {
      let changed = CapturedState(state: false)
      
      let test = MiddleNamePerson()
      withObservationTracking {
        _blackHole(test.lastName)
      } onChange: {
        changed.state = true
      }
      
      test.firstName = "c"
      XCTAssertEqual(changed.state, false)
    }
    
    func testTrackingComputed() throws {
      let changed = CapturedState(state: false)
      
      let test = MiddleNamePerson()
      withObservationTracking {
        _blackHole(test.fullName)
      } onChange: {
        changed.state = true
      }
      
      test.middleName = "c"
      XCTAssertEqual(changed.state, true)
      changed.state = false
      test.middleName = "c"
      XCTAssertEqual(changed.state, false)
    }
    
    func testGraphChanges() throws {
      let changed = CapturedState(state: false)
      
      let test = MiddleNamePerson()
      let friend = MiddleNamePerson()
      test.friends.append(friend)
      withObservationTracking {
        _blackHole(test.friends.first?.fullName)
      } onChange: {
        changed.state = true
      }

      test.middleName = "c"
      XCTAssertEqual(changed.state, false)
      friend.middleName = "c"
      XCTAssertEqual(changed.state, true)
    }
    
    func testNesting() throws {
      let changedOuter = CapturedState(state: false)
      let changedInner = CapturedState(state: false)
      
      let test = MiddleNamePerson()
      withObservationTracking {
        withObservationTracking {
          _blackHole(test.firstName)
        } onChange: {
          changedInner.state = true
        }
      } onChange: {
        changedOuter.state = true
      }
      
      test.firstName = "c"
      XCTAssertEqual(changedInner.state, true)
      XCTAssertEqual(changedOuter.state, true)
      changedOuter.state = false
      test.firstName = "c"
      XCTAssertEqual(changedOuter.state, false)
    }
    
    func testAccessAndMutation() throws {
      let accessKeyPath = CapturedState<PartialKeyPath<ImplementsAccessAndMutation>?>(state: nil)
      let mutationKeyPath = CapturedState<PartialKeyPath<ImplementsAccessAndMutation>?>(state: nil)
      let test = ImplementsAccessAndMutation { keyPath in
        accessKeyPath.state = keyPath
      } withMutationCalled: { keyPath in
        mutationKeyPath.state = keyPath
      }
      
      XCTAssertEqual(accessKeyPath.state, nil)
      _blackHole(test.field)
      XCTAssertEqual(accessKeyPath.state, \.field)
      XCTAssertEqual(mutationKeyPath.state, nil)
      accessKeyPath.state = nil
      test.field = 123
      XCTAssertEqual(accessKeyPath.state, nil)
      XCTAssertEqual(mutationKeyPath.state, \.field)
    }
    
    func testIgnoresNoChange() throws {
      let changed = CapturedState(state: false)
      
      let test = HasIgnoredProperty()
      withObservationTracking {
        _blackHole(test.ignored)
      } onChange: {
        changed.state = true
      }
      
      test.ignored = 122112
      XCTAssertEqual(changed.state, false)
      changed.state = false
      test.field = 3429
      XCTAssertEqual(changed.state, false)
    }
    
    func testIgnoresChange() throws {
      let changed = CapturedState(state: false)
      
      let test = HasIgnoredProperty()
      withObservationTracking {
        _blackHole(test.ignored)
        _blackHole(test.field)
      } onChange: {
        changed.state = true
      }
      
      test.ignored = 122112
      XCTAssertEqual(changed.state, false)
      changed.state = false
      test.field = 3429
      XCTAssertEqual(changed.state, true)
    }

    @MainActor func testIsolatedClass() throws {
      let changed = CapturedState(state: false)
      
      let test = IsolatedClass()
      withObservationTracking {
        _blackHole(test.test)
      } onChange: {
        changed.state = true
      }
      
      test.test = "c"
      XCTAssertEqual(changed.state, true)
      changed.state = false
      test.test = "c"
      XCTAssertEqual(changed.state, false)
    }

    func testRecursiveTrackingInnerThenOuter() throws {
      let obj = RecursiveOuter()
      obj.recursiveTrackingCalls()
      obj.inner.value = "test"
      XCTAssertEqual(obj.innerEventCount, 1)
      XCTAssertEqual(obj.outerEventCount, 1)
      obj.recursiveTrackingCalls()
      obj.value = "test"
      XCTAssertEqual(obj.innerEventCount, 1)
      XCTAssertEqual(obj.outerEventCount, 2)
    }

    func testRecursiveTrackingOuterThenInner() throws {
      let obj = RecursiveOuter()
      obj.recursiveTrackingCalls()
      obj.value = "test"
      XCTAssertEqual(obj.innerEventCount, 0)
      XCTAssertEqual(obj.outerEventCount, 1)
      obj.recursiveTrackingCalls()
      obj.inner.value = "test"
      XCTAssertEqual(obj.innerEventCount, 2)
      XCTAssertEqual(obj.outerEventCount, 2)
    }




}
