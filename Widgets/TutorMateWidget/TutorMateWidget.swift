import WidgetKit
import SwiftUI

private let tutorMateAppGroup = "group.com.example.tutormate"
private let nextClassStorageKey = "tutormate.widget.nextClass"

struct TutorMateWidgetEntry: TimelineEntry {
    let date: Date
    let classTitle: String
    let classTime: String
    let tutorName: String
    let attendanceStreak: String
}

struct TutorMateWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> TutorMateWidgetEntry {
        TutorMateWidgetEntry(
            date: .now,
            classTitle: "Grade 11 Mathematics",
            classTime: "10:30 AM · Room 02",
            tutorName: "Niska Wijesinghe",
            attendanceStreak: "5 classes"
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TutorMateWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : readSharedEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TutorMateWidgetEntry>) -> Void) {
        let entry = readSharedEntry()
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }

    private func readSharedEntry() -> TutorMateWidgetEntry {
        guard let defaults = UserDefaults(suiteName: tutorMateAppGroup),
              let data = defaults.data(forKey: nextClassStorageKey),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return TutorMateWidgetEntry(
                date: .now,
                classTitle: "Open TutorMate",
                classTime: "No shared class data yet",
                tutorName: "Tutor not set",
                attendanceStreak: "0 classes"
            )
        }

        return TutorMateWidgetEntry(
            date: .now,
            classTitle: payload["classTitle"] ?? "No upcoming class",
            classTime: payload["classTime"] ?? "Open TutorMate to see your schedule",
            tutorName: payload["tutorName"] ?? "Tutor not set",
            attendanceStreak: payload["attendanceStreak"] ?? "0 classes"
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
        .widgetURL(URL(string: "tutormate://student/home"))
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
