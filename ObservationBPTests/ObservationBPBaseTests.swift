//
//  ObservationBPBaseTests.swift
//  ObservationBPTests
//
//  Created by Wei Wang on 2023/08/03.
//

import XCTest
@testable import ObservationBP

fileprivate final class SamplePerson: Observable {
    init() {
    }

    var name: String {
        get {
            _registrar.access(self, keyPath: \.name)
            return _name
        }
        set {
            _registrar.withMutation(of: self, keyPath: \.name) {
                _name = newValue
            }
        }
    }

    var age: Int {
        get {
            _registrar.access(self, keyPath: \.age)
            return _age
        }
        set {
            _registrar.withMutation(of: self, keyPath: \.age) {
                _age = newValue
            }
            
        }
    }
    var _name = "Tom"
    var _age = 25

    var _registrar = ObservationRegistrar()
}

private let sample = SamplePerson()

final class MyObservationTests: XCTestCase {
    var numberOfCalls = 0
    func testObservation() throws {
            withObservationTracking {
                _ = sample.name
            } onChange: {
                self.numberOfCalls += 1
            }
            XCTAssertEqual(numberOfCalls, 0)
            sample.age += 1
            XCTAssertEqual(numberOfCalls, 0)
            sample.name.append("!")
            XCTAssertEqual(numberOfCalls, 1)
            sample.name.append("!")
            XCTAssertEqual(numberOfCalls, 1)
        }

}
