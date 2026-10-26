import SwiftUI

struct StudentProgressView: View {
    @EnvironmentObject private var app: AppController
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Your progress", subtitle: "Celebrate your growth and track your results.")
                TMCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "OVERALL PERFORMANCE")
                            Text("86%").font(.system(size: 42, weight: .bold, design: .rounded)).foregroundStyle(TMStyle.blue)
                            Text("Great work — keep going!").font(.subheadline).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                        Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 40)).foregroundStyle(TMStyle.green)
                    }
                    ProgressView(value: 0.86).tint(TMStyle.blue)
                }
                TMCard {
                    Text("Subject progress").font(.headline)
                    subjectRow("Mathematics", score: 0.86, tint: TMStyle.blue)
                    subjectRow("ICT", score: 0.92, tint: TMStyle.violet)
                    subjectRow("Physics", score: 0.81, tint: TMStyle.orange)
                }
                TMCard {
                    Text("Achievements").font(.headline)
                    achievement("5 Class Streak", icon: "flame.fill", tint: TMStyle.orange)
                    achievement("Perfect Week", icon: "trophy.fill", tint: TMStyle.violet)
                    achievement("100 Points", icon: "sparkles", tint: TMStyle.blue)
                }
                TMCard {
                    Text("Recent assessments").font(.headline)
                    ForEach(app.assessments) { assessment in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assessment.title).font(.subheadline.weight(.semibold))
                                Text("\(assessment.subject) · \(assessment.dateLabel)").font(.caption).foregroundStyle(TMStyle.muted)
                            }
                            Spacer()
                            Text("\(assessment.score)%").font(.headline).foregroundStyle(TMStyle.blue)
                        }
                        Divider()
                    }
                }
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas).navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
    }
    private func subjectRow(_ title: String, score: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.subheadline.weight(.medium)); Spacer(); Text("\(Int(score * 100))%").font(.subheadline.weight(.bold)).foregroundStyle(tint) }
            ProgressView(value: score).tint(tint)
        }.padding(.vertical, 5)
    }
    private func achievement(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 42, height: 42).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
            StatusPill(text: "Unlocked", color: tint)
        }
    }
}
