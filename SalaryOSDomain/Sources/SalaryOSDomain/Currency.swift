import Foundation

public enum CurrencyError: Error, Equatable {
    case invalidISO4217Code(String)
}

/// An ISO 4217 currency code with its standard minor-unit precision.
public struct Currency: Hashable, Codable, Sendable {
    public let code: String
    public let fractionDigits: Int

    public init(code: String) throws {
        let normalizedCode = code.uppercased()
        guard normalizedCode.count == 3,
              normalizedCode.unicodeScalars.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }),
              Locale.commonISOCurrencyCodes.contains(normalizedCode)
        else {
            throw CurrencyError.invalidISO4217Code(code)
        }
        self.code = normalizedCode
        self.fractionDigits = Self.minorUnits[normalizedCode] ?? 2
    }

    private static let minorUnits: [String: Int] = [
        "BIF": 0, "CLP": 0, "DJF": 0, "GNF": 0, "ISK": 0, "JPY": 0,
        "KMF": 0, "KRW": 0, "PYG": 0, "RWF": 0, "UGX": 0, "UYI": 0,
        "VND": 0, "VUV": 0, "XAF": 0, "XOF": 0, "XPF": 0,
        "BHD": 3, "IQD": 3, "JOD": 3, "KWD": 3, "LYD": 3, "OMR": 3,
        "TND": 3
    ]
}

extension Currency {
    private enum CodingKeys: String, CodingKey { case code }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(code: container.decode(String.self, forKey: .code))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
    }
}
