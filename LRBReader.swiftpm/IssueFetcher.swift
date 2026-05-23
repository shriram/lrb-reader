import Foundation

enum IssueFetcherError: Error {
    case badResponse
    case decodingFailed
}

actor IssueFetcher {
    static let shared = IssueFetcher()

    /// Fetches the archive page for the given volume and returns the issue numbers present.
    /// Network call only happens when the user explicitly asks for it — never in the background.
    func fetchIssueNumbers(forVolume volume: Int) async throws -> [Int] {
        let paddedVol = String(format: "%02d", volume)
        let url = URL(string: "https://www.lrb.co.uk/archive/v\(paddedVol)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw IssueFetcherError.badResponse
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw IssueFetcherError.decodingFailed
        }
        return Self.parseIssueNumbers(html: html, volume: volume)
    }

    static func parseIssueNumbers(html: String, volume: Int) -> [Int] {
        let paddedVol = String(format: "%02d", volume)
        let pattern = "/the-paper/v\(paddedVol)/n(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))

        var seen = Set<Int>()
        for m in matches {
            let numberStr = nsHtml.substring(with: m.range(at: 1))
            if let number = Int(numberStr) { seen.insert(number) }
        }
        return seen.sorted()
    }
}
