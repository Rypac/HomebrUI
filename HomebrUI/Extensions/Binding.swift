import SwiftUI

extension Binding {
  var optional: Binding<Value?> {
    Binding<Value?>(
      get: { wrappedValue },
      set: { newValue in
        if let value = newValue {
          wrappedValue = value
        }
      }
    )
  }

  func nonOptional<T>(withDefault defaultValue: T) -> Binding<T> where Value == T? {
    Binding<T>(
      get: { wrappedValue ?? defaultValue },
      set: { wrappedValue = $0 }
    )
  }
}
