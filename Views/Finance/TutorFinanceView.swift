import SwiftUI
import Charts

struct TutorFinanceView: View {
    @EnvironmentObject private var app: AppController
    private var chartData: [(String, Double)] { [("Jan", 240), ("Feb", 310), ("Mar", 290), ("Apr", 420), ("May", 380), ("Jun", app.collectedIncome + 280)] }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Finance overview", subtitle: "Track income, collections and outstanding tuition.")
                TMCard {
                    Eyebrow(text: "TOTAL INCOME")
                    Text("$\(Int(app.collectedIncome))").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(TMStyle.ink)
                    HStack {
                        Label("Payments collected", systemImage: "arrow.up.right").foregroundStyle(TMStyle.green)
                        Spacer()
                        StatusPill(text: "\(app.payments.filter(\.isPaid).count) paid")
                    }.font(.caption)
                    Chart(chartData, id: \.0) { item in
                        BarMark(x: .value("Month", item.0), y: .value("Income", item.1))
                            .foregroundStyle(TMStyle.blue.gradient).cornerRadius(5)
                    }.frame(height: 210)
                    Text("Monthly bars are a sample illustration. Totals above use saved payments.")
                        .font(.caption2)
                        .foregroundStyle(TMStyle.muted)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Outstanding", value: "$\(Int(app.outstandingIncome))", detail: "Unpaid fees", icon: "clock.fill", tint: TMStyle.orange)
                    MetricTile(title: "Collection rate", value: "\(app.payments.isEmpty ? 0 : app.payments.filter(\.isPaid).count * 100 / app.payments.count)%", detail: "Of recorded payments", icon: "chart.pie.fill", tint: TMStyle.green)
                }
                TMCard {
                    Text("Income by class").font(.headline)
                    Text("Sample breakdown for layout. Not loaded from Firestore.")
                        .font(.caption2)
                        .foregroundStyle(TMStyle.muted)
                    incomeRow("Grade 11 Mathematics", value: "$240", percent: 0.8)
                    incomeRow("ICT Group B", value: "$180", percent: 0.6)
                    incomeRow("Physics Revision", value: "$120", percent: 0.4)
                }
                TMCard {
                    Text("Recent transactions").font(.headline)
                    ForEach(app.payments.prefix(5)) { payment in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(payment.studentName).font(.subheadline.weight(.semibold))
                                Text(payment.description).font(.caption).foregroundStyle(TMStyle.muted)
                            }
                            Spacer()
                            Text("\(payment.isPaid ? "+" : "")$\(Int(payment.amount))").font(.subheadline.weight(.bold)).foregroundStyle(payment.isPaid ? TMStyle.green : TMStyle.orange)
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 950).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
    }
    private func incomeRow(_ title: String, value: String, percent: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.subheadline); Spacer(); Text(value).font(.subheadline.weight(.semibold)) }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(TMStyle.line)
                    Capsule().fill(TMStyle.blue).frame(width: proxy.size.width * percent)
                }
            }.frame(height: 7)
        }
    }
}
