import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject private var app: AppController
    var onOpenClasses: () -> Void
    var onOpenProgress: () -> Void
    @State private var showScan = false
    private var nextClass: ClassSession { app.sessions.sorted { $0.date < $1.date }.first ?? ClassSession(title: "Grade 11 Mathematics", subject: "Mathematics", date: .now, time: "10:30 AM", duration: "60 min", location: "Room 02", students: 5) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Eyebrow(text: "STUDENT SPACE")
                        Text("Hello, \(app.displayName.split(separator: " ").first.map(String.init) ?? "Student") 👋").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(TMStyle.ink)
                        Text("Ready for your next class?").font(.subheadline).foregroundStyle(TMStyle.muted)
                    }
                    Spacer()
                    AvatarView(name: app.displayName)
                }
                TMCard(padding: 0) {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(colors: [TMStyle.blue, TMStyle.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack { StatusPill(text: "UP NEXT", color: .white); Spacer(); Image(systemName: "sparkles").foregroundStyle(.white.opacity(0.8)) }
                            Text(nextClass.title).font(.title2.bold()).foregroundStyle(.white)
                            Label("\(nextClass.time) · \(nextClass.duration)", systemImage: "clock").font(.subheadline).foregroundStyle(.white.opacity(0.9))
                            Label(nextClass.location, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.white.opacity(0.9))
                            Button { showScan = true } label: {
                                Label(app.nfcCheckedIn ? "Checked in" : "Check in with NFC", systemImage: app.nfcCheckedIn ? "checkmark.circle.fill" : "wave.3.right")
                                    .font(.subheadline.weight(.bold)).foregroundStyle(TMStyle.blue).padding(.horizontal, 16).padding(.vertical, 11).background(.white, in: Capsule())
                            }.padding(.top, 4)
                        }.padding(20)
                    }.clipShape(RoundedRectangle(cornerRadius: 20))
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    studentMetric("94%", title: "Attendance", icon: "checkmark.circle.fill", tint: TMStyle.green)
                    studentMetric("86%", title: "Avg. score", icon: "chart.bar.fill", tint: TMStyle.violet)
                    studentMetric("5", title: "Class streak", icon: "flame.fill", tint: TMStyle.orange)
                }
                TMCard {
                    HStack {
                        Text("Today's classes").font(.headline)
                        Spacer()
                        Button("See all", action: onOpenClasses).font(.caption.weight(.semibold))
                    }
                    ForEach(app.sessions.prefix(2)) { session in
                        ClassSummaryRow(session: session)
                    }
                }
                TMCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "YOUR MOMENTUM")
                            Text("\(app.studentPoints) points").font(.title2.bold()).foregroundStyle(TMStyle.ink)
                            Text("You're on a 5 class streak!").font(.subheadline).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                        Image(systemName: "trophy.fill").font(.system(size: 36)).foregroundStyle(TMStyle.orange)
                    }
                    Button("View progress and achievements", action: onOpenProgress).font(.subheadline.weight(.semibold))
                }
                TMCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Latest result").font(.headline)
                            Text(app.assessments.first?.title ?? "Algebra Quiz").font(.subheadline).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                        Text("\(app.assessments.first?.score ?? 86)%").font(.system(size: 27, weight: .bold, design: .rounded)).foregroundStyle(TMStyle.blue)
                    }
                }
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas).navigationTitle("Home").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showScan) { NFCScanSheet(isTutor: false) }
    }
    private func studentMetric(_ value: String, title: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(value).font(.title2.bold()).foregroundStyle(TMStyle.ink)
            Text(title).font(.caption).foregroundStyle(TMStyle.muted)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12).background(.white, in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(TMStyle.line))
    }
}
