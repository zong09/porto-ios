import Foundation

// The backend serializes some Postgres `numeric` columns as JSON STRINGS (verified against live
// /transactions: quantity/price/fee arrive as "18", "189.5"). Others (summary, position) arrive as
// JSON numbers. These helpers accept either representation so decoding never breaks on that.
extension KeyedDecodingContainer {
    func decodeFlexibleDouble(forKey key: Key) throws -> Double {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key), let d = Double(s) { return d }
        throw DecodingError.dataCorruptedError(forKey: key, in: self,
            debugDescription: "Expected Double or numeric String")
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let d = try? decode(Double.self, forKey: key) { return d }
        if let s = try? decode(String.self, forKey: key) { return Double(s) }
        return nil
    }
}
