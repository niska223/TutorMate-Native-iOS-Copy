import WidgetKit
import SwiftUI

struct TutorMateWidgetEntry: TimelineEntry {
    let date: Date
    let classTitle: String
    let classTime: String
    let tutorName: String
    let attendanceStreak: String
    let subject: String
    let classDate: String
}

struct TutorMateWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TutorMateWidgetEntry {
        TutorMateWidgetEntry(
            date: .now,
            classTitle: "Open TutorMate",
            classTime: "Your schedule will appear here",
            tutorName: "",
            attendanceStreak: "Streak unavailable",
            subject: "",
            classDate: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TutorMateWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : readSharedEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TutorMateWidgetEntry>) -> Void) {
        let entry = readSharedEntry()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60))))
    }

    private func readSharedEntry() -> TutorMateWidgetEntry {
        guard let payload = WidgetSharedStore.load(), payload.role == "tutor" else {
            return TutorMateWidgetEntry(
                date: .now,
                classTitle: "Open TutorMate",
                classTime: "Tutor schedule unavailable",
                tutorName: "",
                attendanceStreak: "Streak unavailable",
                subject: "",
                classDate: ""
            )
        }
        let noClass = payload.classTitle == nil
        return TutorMateWidgetEntry(
            date: .now, classTitle: payload.classTitle ?? "No upcoming class",
            classTime: noClass ? "No upcoming classes" : (payload.classTime ?? "Time unavailable"),
            tutorName: payload.tutorName ?? "",
            attendanceStreak: payload.attendanceStreak.map { "\($0) day streak" } ?? "Streak unavailable",
            subject: payload.subject ?? "",
            classDate: payload.classDate?.formatted(date: .abbreviated, time: .omitted) ?? ""
        )
    }
}

struct TutorMateWidgetView: View {
    var entry: TutorMateWidgetProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("TutorMate", systemImage: "graduationcap.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            Text("NEXT CLASS")
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            Text(entry.classTitle)
                .font(.headline)
                .lineLimit(2)

            if !entry.subject.isEmpty { Text(entry.subject).font(.caption.weight(.semibold)).foregroundStyle(.blue) }
            if !entry.classDate.isEmpty { Text(entry.classDate).font(.caption).foregroundStyle(.secondary) }

            Label(entry.classTime, systemImage: "clock")
                .font(.caption)
                .lineLimit(2)

            if family != .systemSmall {
                Divider()
                HStack(alignment: .center, spacing: 8) {
                    Label(entry.tutorName, systemImage: "person.fill")
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 4)
                    Label(entry.attendanceStreak, systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                }
                .font(.caption)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(.orange)
                    Text(entry.attendanceStreak)
                    Spacer(minLength: 2)
                }
                .font(.caption2)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("TutorMate. Next class: \(entry.classTitle). \(entry.subject). \(entry.classDate), \(entry.classTime). \(entry.attendanceStreak).")
        .widgetURL(URL(string: "tutormate://"))
    }
}

@main
struct TutorMateWidget: Widget {
    let kind = "TutorMateWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TutorMateWidgetProvider()) { entry in
            TutorMateWidgetView(entry: entry)
        }
        .configurationDisplayName("TutorMate Next Class")
        .description("See your next class, tutor and attendance streak.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
