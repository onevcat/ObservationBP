//
//  PerformanceComparingView.swift
//  ObservationBPSwiftUIDemo
//
//  Created by Wei Wang on 2023/08/04.
//

import SwiftUI
import ObservationBP

struct PerformanceComparingView: View {
    
    private var person = Person(name: "Tom", age: 12)
    
    var body: some View {
        ObservationView {
            VStack {
                
                // Self re-rendered
                Text(person.name)
                Text("\(person.age)")
                
                // Self & AgeView re-rendered
                // NameView(name: person.name)
                // AgeView(age: person.age)
                
                // Only PersonAgeView re-rendered
                // PersonNameView(person: person)
                // PersonAgeView(person: person)
                
                HStack {
                    Button("+") { person.age += 1 }
                    Button("-") { person.age -= 1 }
                }
            }
            .padding()
        }
    }
}

struct NameView: View {
    let name: String
    var body: some View {
        if #available(iOS 15.0, *) {
            Self._printChanges()
        }
        return Text(name)
    }
}

struct AgeView: View {
    let age: Int
    var body: some View {
        if #available(iOS 15.0, *) {
            Self._printChanges()
        }
        
        return Text("\(age)")
    }
}

struct PersonNameView: View {
    let person: Person
    var body: some View {
        if #available(iOS 15.0, *) {
            Self._printChanges()
        }
        return ObservationView {
            return Text(person.name)
        }
    }
}

struct PersonAgeView: View {
    let person: Person
    var body: some View {
        if #available(iOS 15.0, *) {
            Self._printChanges()
        }
        return ObservationView {
            Text("\(person.age)")
        }
    }
}

#Preview {
    PerformanceComparingView()
}
