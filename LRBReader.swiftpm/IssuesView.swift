import SwiftUI
import SwiftData

struct IssuesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Issue.volume, order: .reverse),
                  SortDescriptor(\Issue.number, order: .reverse)])
    private var allIssues: [Issue]

    let onOpen: (URL) -> Void

    @State private var expandedYears: Set<Int> = []
    @State private var loadingYears: Set<Int> = []
    @State private var loadErrors: [Int: String] = [:]

    private var years: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        // LRB started in October 1979 (volume 1).
        return Array((1979...currentYear).reversed())
    }

    private func issues(for year: Int) -> [Issue] {
        allIssues.filter { $0.year == year }
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
        let isExpanded = Binding(
            get: { expandedYears.contains(year) },
            set: { newValue in
                if newValue {
                    expandedYears.insert(year)
                    if issuesForYear.isEmpty && !loadingYears.contains(year) {
                        Task { await loadYear(year) }
                    }
                } else {
                    expandedYears.remove(year)
                }
            }
        )

        DisclosureGroup(isExpanded: isExpanded) {
            if loadingYears.contains(year) && issuesForYear.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading…").foregroundStyle(.secondary)
                }
            } else if let err = loadErrors[year], issuesForYear.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Couldn't load this year")
                        .foregroundStyle(.secondary)
                    Text(err).font(.caption).foregroundStyle(.secondary)
                    Button("Retry") { Task { await loadYear(year) } }
                        .buttonStyle(.bordered)
                }
            } else if issuesForYear.isEmpty {
                Text("No issues loaded yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(issuesForYear) { issue in
                    Button {
                        onOpen(issue.url)
                    } label: {
                        HStack {
                            Text(issue.label)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                Button {
                    Task { await loadYear(year) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .disabled(loadingYears.contains(year))
            }
        } label: {
            HStack {
                Text(String(year))
                    .font(.headline)
                Spacer()
                if !issuesForYear.isEmpty {
                    Text("\(issuesForYear.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Vol. \(volume)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @MainActor
    private func loadYear(_ year: Int) async {
        let volume = Issue.volume(forYear: year)
        loadingYears.insert(year)
        loadErrors[year] = nil
        defer { loadingYears.remove(year) }

        do {
            let numbers = try await IssueFetcher.shared.fetchIssueNumbers(forVolume: volume)
            let existing = Set(issues(for: year).map(\.number))
            let now = Date.now
            for n in numbers where !existing.contains(n) {
                modelContext.insert(Issue(volume: volume, number: n, fetchedAt: now))
            }
            // Touch fetchedAt on the existing ones so we know we re-verified.
            for issue in issues(for: year) where numbers.contains(issue.number) {
                issue.fetchedAt = now
            }
        } catch {
            loadErrors[year] = (error as NSError).localizedDescription
        }
    }
}
