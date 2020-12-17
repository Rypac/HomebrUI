import Combine

/// Similar to the builtin `Published` property wrapper except that it will not automatically
/// trigger `objectWillChange` the publisher that SwiftUI uses to connect `ObservableObject`.
///
/// Inspired by: https://www.swiftbysundell.com/articles/connecting-and-merging-combine-publishers-in-swift/
@propertyWrapper
public struct Input<Value> {
  private let subject: CurrentValueSubject<Value, Never>

  public init(wrappedValue: Value) {
    subject = CurrentValueSubject(wrappedValue)
  }

  public var wrappedValue: Value {
    get { subject.value }
    set { subject.send(newValue) }
  }

  public var projectedValue: AnyPublisher<Value, Never> {
    subject.eraseToAnyPublisher()
  }
}
