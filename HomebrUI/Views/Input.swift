import Combine

@propertyWrapper
public struct Input<Value> {
  public var wrappedValue: Value {
    get { subject.value }
    set { subject.send(newValue) }
  }

  public var projectedValue: AnyPublisher<Value, Never> {
    subject.eraseToAnyPublisher()
  }

  private let subject: CurrentValueSubject<Value, Never>

  public init(wrappedValue: Value) {
    subject = CurrentValueSubject(wrappedValue)
  }
}
