# Observation Back-Porting

Proof of Concept for back-porting Observation framework to earlier iOS versions.

The same APIs as the Observation framework are provided but without the limitation of iOS 17. 

Verified on Version 15.0 beta 5 (15A5209g). May break with a future version of Xcode.

Just a toy and only for PoC. Do not use it in your production code (or at your own risk)!

### Usage

#### Macro

Just as the official Observation framework, but importing `ObservationBP`:

```swift
import ObservationBP

@Observable fileprivate class Person {
    internal init(name: String, age: Int) {
        self.name = name
        self.age = age
    }

    var name: String = ""
    var age: Int = 0
}
```

Results in:

![](https://github.com/onevcat/ObservationBP/assets/1019875/9f3e4c46-ef2e-4c93-b732-33599ddb5f55)

#### Access Tracking

```swift
let p = Person(name: "Tom", age: 12)
withObservationTracking {
    _ = p.name
} onChange: {
    print("Changed!")
}

p.age = 20
print("No log")

p.name = "John"
print("'Changed' is printed")

// No log
// Changed!
// 'Changed' is printed
```

#### SwiftUI