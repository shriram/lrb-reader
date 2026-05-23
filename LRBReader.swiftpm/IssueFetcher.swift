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

    /// Fetches an issue's TOC page and returns canonical article URL strings.
    /// `issuePath` is like "/the-paper/v48/n09".
    func fetchArticleURLs(forIssuePath issuePath: String) async throws -> [String] {
        let url = URL(string: "https://www.lrb.co.uk\(issuePath)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw IssueFetcherError.badResponse
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw IssueFetcherError.decodingFailed
        }
        return Self.parseArticleURLs(html: html, issuePath: issuePath)
    }

    static func parseArticleURLs(html: String, issuePath: String) -> [String] {
        // Match issuePath + "/{slug}" or issuePath + "/{slug}/{slug}".
        // Slugs use lowercase letters, digits, and . _ - (e.g. "j.-robert-lennon").
        let escaped = NSRegularExpression.escapedPattern(for: issuePath)
        let pattern = #"\#(escaped)/[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsHtml = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHtml.length))

        var seen = Set<String>()
        for m in matches {
            let path = nsHtml.substring(with: m.range)
            seen.insert("https://www.lrb.co.uk\(path)")
        }
        return Array(seen)
    }
}
