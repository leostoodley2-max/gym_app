import Foundation

/// Worcestershire's local-authority districts, used to group gyms.
public enum District: String, Codable, CaseIterable, Hashable, Sendable {
    case worcester, wychavon, malvernHills, wyreForest, bromsgrove, redditch

    public var displayName: String {
        switch self {
        case .worcester: return "Worcester"
        case .wychavon: return "Wychavon (Droitwich, Evesham, Pershore)"
        case .malvernHills: return "Malvern Hills"
        case .wyreForest: return "Wyre Forest (Kidderminster, Stourport, Bewdley)"
        case .bromsgrove: return "Bromsgrove"
        case .redditch: return "Redditch"
        }
    }
}

public enum GymKind: String, Codable, CaseIterable, Hashable, Sendable {
    case chain, independent, leisure, strength, crossfit, college, healthClub

    public var displayName: String {
        switch self {
        case .chain: return "Chain gym"
        case .independent: return "Independent"
        case .leisure: return "Leisure centre"
        case .strength: return "Strength gym"
        case .crossfit: return "CrossFit"
        case .college: return "College gym"
        case .healthClub: return "Health club"
        }
    }
}

/// How confidently a gym's details were confirmed during research.
public enum ListingConfidence: String, Codable, Hashable, Sendable {
    case high, medium, low
}

public struct Gym: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let brand: String
    public let city: String
    public let district: District
    public let address: String
    public let postcode: String
    public let postcodeArea: String
    public let kind: GymKind
    public let listing: ListingConfidence

    public init(id: String, name: String, brand: String, city: String, district: District, address: String,
                postcode: String, postcodeArea: String, kind: GymKind, listing: ListingConfidence) {
        self.id = id
        self.name = name
        self.brand = brand
        self.city = city
        self.district = district
        self.address = address
        self.postcode = postcode
        self.postcodeArea = postcodeArea
        self.kind = kind
        self.listing = listing
    }

    public var subtitle: String {
        postcode.isEmpty ? city : "\(city) · \(postcode)"
    }
}
