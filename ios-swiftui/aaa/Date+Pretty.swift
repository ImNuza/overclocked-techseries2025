import Foundation

private let _prettyDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateStyle = .medium
    f.timeStyle = .none
    return f
}()

extension Date {
    var pretty: String {
        _prettyDateFormatter.string(from: self)
    }
}
