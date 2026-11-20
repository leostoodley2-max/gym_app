import Foundation

public enum UKNation: String, Codable, CaseIterable, Hashable, Sendable {
    case england, scotland, wales, northernIreland

    public var displayName: String {
        switch self {
        case .england: return "England"
        case .scotland: return "Scotland"
        case .wales: return "Wales"
        case .northernIreland: return "Northern Ireland"
        }
    }
}

public struct Gym: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let city: String
    public let nation: UKNation
    public let postcodeArea: String

    public init(id: String, name: String, city: String, nation: UKNation, postcodeArea: String) {
        self.id = id
        self.name = name
        self.city = city
        self.nation = nation
        self.postcodeArea = postcodeArea
    }

    public var subtitle: String { "\(city), \(nation.displayName)" }
}
