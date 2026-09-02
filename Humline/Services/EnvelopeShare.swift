import Foundation

enum EnvelopeShare {
    static let fileExtension = "humline"
    static let uti = "com.catfordlabs.humline.flight"

    static func writeTemporary(_ flight: SharedFlight) -> URL? {
        let filename = "\(flight.melodyId)-flight.\(fileExtension)"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(flight)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func load(from url: URL) -> SharedFlight? {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(SharedFlight.self, from: data)
    }
}
