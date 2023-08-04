//
//  ObservationBPMarcoTests.swift
//  ObservationBPTests
//
//  Created by Wei Wang on 2023/08/03.
//

import XCTest
import ObservationBP

@Observable fileprivate class SamplePerson {
    internal init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    var name: String = ""
    var age: Int = 0
}


final class ObservationBPMarcoTests: XCTestCase {
    func testExample() throws {
        let p = SamplePerson(name: "Tom", age: 12)
        withObservationTracking {
            _ = p.name
        } onChange: {
            print("Changed!")
        }
        
        p.age = 20
        print("No log")
        
        p.name = "John"
        print("'Changed' is printed")
    }
}
