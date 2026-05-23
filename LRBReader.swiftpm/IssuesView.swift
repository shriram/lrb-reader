import SwiftUI
import SwiftData

struct IssuesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Issue.volume, order: .reverse),
                  SortDescriptor(\Issue.number, order: .reverse)])
    private var allIssues: [Issue]
    @Query private var allArticles: [Article]
    @Query private var allReadArticles: [ReadArticle]

    let onOpen: (URL) -> Void

    @State private var expandedYears: Set<Int> = []
    @State private var loadingYears: Set<Int> = []
    @State private var loadErrors: [Int: String] = [:]

    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        return Array((1979...currentYear).reversed())
    }

    private func issues(for year: Int) -> [Issue] {
        allIssues.filter { $0.year == year }
    }

    /// Articles grouped by their issue path.
    private var articlesByIssue: [String: Set<String>] {
        Dictionary(grouping: allArticles, by: \.issuePath)
            .mapValues { Set($0.map(\.urlString)) }
    }

    private var readUrlSet: Set<String> { Set(allReadArticles.map(\.urlString)) }

    private func progress(forIssuePath path: String) -> (known: Int, read: Int) {
        let known = articlesByIssue[path] ?? []
        let read = known.intersection(readUrlSet).count
        return (known.count, read)
    }

    /// Has this issue's TOC been fetched? Until then, counts are meaningless.
    private func hasArticleData(_ issue: Issue) -> Bool {
        issue.articlesFetchedAt != nil
    }

    private func isIssueComplete(_ issue: Issue) -> Bool {
        guard hasArticleData(issue) else { return false }
        let (known, read) = progress(forIssuePath: issue.path)
        return known > 0 && known == read
    }

    /// Year-level summary: how many issues in this year have article data, and
    /// how many of *those* are complete. We only display a count when every
    /// issue has data (otherwise the number would mislead).
    private struct YearSummary {
        var totalIssues: Int
        var withData: Int
        var complete: Int
        var allLoaded: Bool { totalIssues > 0 && withData == totalIssues }
    }

    private func yearSummary(_ year: Int) -> YearSummary {
        let ys = issues(for: year)
        let withData = ys.filter(hasArticleData).count
        let complete = ys.filter(isIssueComplete).count
        return YearSummary(totalIssues: ys.count, withData: withData, complete: complete)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(years, id: \.self) { year in
                    yearSection(year: year)
                }
            }
            .navigationTitle("Issues")
        }
    }

    @ViewBuilder
    private func yearSection(year: Int) -> some View {
        let volume = Issue.volume(forYear: year)
        let issuesForYear = issues(for: year)
        let summary = yearSummary(year)
        let yearComplete = summary.allLoaded && summary.complete == summary.totalIssues
        let isLoading = loadingYears.contains(year)

        let isExpanded = Binding(
            get: { expandedYears.contains(year) },
            set: { newValue in
                if newValue {
                    expandedYears.insert(year)
                    if !isLoading && needsLoad(year: year) {
                        Task { await loadYear(year) }
                    }
                } else {
                    expandedYears.remove(year)
                }
            }
        )

        DisclosureGroup(isExpanded: isExpanded) {
            if isLoading && issuesForYear.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading…").foregroundStyle(.secondary)
                }
            } else if let err = loadErrors[year], issuesForYear.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn't load this year").foregroundStyle(.secondary)
                    Text(err).font(.caption).foregroundStyle(.secondary)
                    Button("Retry") { Task { await loadYear(year) } }
                        .buttonStyle(.bordered)
                }
            } else if issuesForYear.isEmpty {
                Text("No issues loaded yet").foregroundStyle(.secondary)
            } else {
                ForEach(issuesForYear) { issue in
                    issueRow(issue)
                }
                Button {
                    Task { await loadYear(year, force: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .disabled(isLoading)
            }
        } label: {
            HStack(spacing: 8) {
                Text(String(year))
                    .font(.headline)
                    .foregroundStyle(yearComplete ? .secondary : .primary)
                if yearComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if summary.allLoaded {
                    Text("\(summary.totalIssues - summary.complete)/\(summary.totalIssues)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text("Vol. \(volume)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(yearComplete ? 0.55 : 1.0)
        }
    }

    @ViewBuilder
    private func issueRow(_ issue: Issue) -> some View {
        let hasData = hasArticleData(issue)
        let (known, read) = progress(forIssuePath: issue.path)
        let complete = hasData && known > 0 && known == read

        Button {
            onOpen(issue.url)
        } label: {
            HStack(spacing: 8) {
                Text(issue.label)
                    .foregroundStyle(complete ? .secondary : .primary)
                if complete {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                Spacer()
                if hasData && known > 0 {
                    Text("\(known - read)/\(known)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .opacity(complete ? 0.6 : 1.0)
        }
    }

    private func needsLoad(year: Int) -> Bool {
        let ys = issues(for: year)
        if ys.isEmpty { return true }
        return ys.contains { $0.articlesFetchedAt == nil }
    }

    @MainActor
    private func loadYear(_ year: Int, force: Bool = false) async {
        let volume = Issue.volume(forYear: year)
        loadingYears.insert(year)
        loadErrors[year] = nil
        defer { loadingYears.remove(year) }

        // Step 1: fetch the issue list for the year, unless we already have it
        // (and aren't being asked to refresh).
        if force || issues(for: year).isEmpty {
            do {
                let numbers = try await IssueFetcher.shared.fetchIssueNumbers(forVolume: volume)
                let existing = Set(issues(for: year).map(\.number))
                let now = Date.now
                for n in numbers where !existing.contains(n) {
                    modelContext.insert(Issue(volume: volume, number: n, fetchedAt: now))
                }
                for issue in issues(for: year) where numbers.contains(issue.number) {
                    issue.fetchedAt = now
                }
            } catch {
                loadErrors[year] = (error as NSError).localizedDescription
                return
            }
        }

        // Step 2: for each issue lacking article data (or all, if `force`),
        // fetch its TOC and harvest article URLs.
        let toFetch = issues(for: year).filter { force || $0.articlesFetchedAt == nil }
        await withTaskGroup(of: (String, [String]?).self) { group in
            for issue in toFetch {
                let issuePath = issue.path
                group.addTask {
                    let urls = try? await IssueFetcher.shared.fetchArticleURLs(forIssuePath: issuePath)
                    return (issuePath, urls)
                }
            }
            for await (issuePath, maybeUrls) in group {
                guard let urls = maybeUrls else { continue }
                let existing = Set(allArticles.filter { $0.issuePath == issuePath }.map(\.urlString))
                for urlString in urls where !existing.contains(urlString) {
                    modelContext.insert(Article(urlString: urlString, issuePath: issuePath))
                }
                if let issue = allIssues.first(where: { $0.path == issuePath }) {
                    issue.articlesFetchedAt = Date()
                }
            }
        }
    }
}
