//
//  ContentView.swift
//  ObservationBPSwiftUIDemo
//
//  Created by Wei Wang on 2023/08/04.
//

import SwiftUI
import ObservationBP

@Observable final class Person {
    var name: String
    var age: Int
    
    init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
}

struct ContentView: View {
    
    private var person = Person(name: "Tom", age: 12)
    
    var body: some View {
        ObservationView {
            VStack {
                Text(person.name)
                Text("\(person.age)")
                HStack {
                    Button("+") { person.age += 1 }
                    Button("-") { person.age -= 1 }
                }
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}
