import SwiftUI
import Charts

struct TutorFinanceView: View {
    @EnvironmentObject private var app: AppController

    private var monthlyIncome: [MonthlyIncome] {
        let calendar = Calendar.current
        let now = Date.now
        return (0..<6).reversed().compactMap { offset -> MonthlyIncome? in
            guard let month = calendar.date(byAdding: .month, value: -offset, to: now),
                  let interval = calendar.dateInterval(of: .month, for: month) else { return nil }
            let collected = app.payments
                .filter { $0.isPaid && interval.contains($0.date) }
                .reduce(0) { $0 + $1.amount }
            return MonthlyIncome(date: interval.start, amount: collected)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Finance overview", subtitle: "Totals are calculated from your saved payment records.")
                TMCard {
                    Eyebrow(text: "TOTAL COLLECTED")
                    Text(app.collectedIncome, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(TMStyle.ink)
                    HStack {
                        Label("Paid payment records", systemImage: "arrow.up.right")
                            .foregroundStyle(TMStyle.green)
                        Spacer()
                        StatusPill(text: "\(app.payments.filter(\.isPaid).count) paid")
                    }
                    .font(.caption)
                    if app.payments.isEmpty {
                        ContentUnavailableView("No payment records", systemImage: "creditcard", description: Text("Saved payments will appear here."))
                    } else {
                        Chart(monthlyIncome) { item in
                            BarMark(x: .value("Month", item.date, unit: .month), y: .value("Collected", item.amount))
                                .foregroundStyle(TMStyle.blue.gradient)
                                .cornerRadius(5)
                        }
                        .frame(height: 210)
                        .accessibilityLabel("Monthly collected payment totals for the last six months")
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricTile(title: "Outstanding", value: app.outstandingIncome.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")), detail: "Unpaid saved records", icon: "clock.fill", tint: TMStyle.orange)
                    MetricTile(title: "Collection rate", value: "\(app.payments.isEmpty ? 0 : app.payments.filter(\.isPaid).count * 100 / app.payments.count)%", detail: "Of recorded payments", icon: "chart.pie.fill", tint: TMStyle.green)
                }

                TMCard {
                    Text("Income by class").font(.headline)
                    Text("Class-level totals are unavailable because payment records are not linked to class IDs.")
                        .font(.body)
                        .foregroundStyle(TMStyle.muted)
                }

                TMCard {
                    Text("Recent transactions").font(.headline)
                    if app.payments.isEmpty {
                        ContentUnavailableView("No recent transactions", systemImage: "list.bullet.rectangle", description: Text("Create a saved payment to see it here."))
                    } else {
                        ForEach(app.payments.sorted { $0.date > $1.date }.prefix(5)) { payment in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(payment.studentName).font(.subheadline.weight(.semibold))
                                    Text(payment.description).font(.footnote).foregroundStyle(TMStyle.muted)
                                }
                                Spacer()
                                Text(payment.amount, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(payment.isPaid ? TMStyle.green : TMStyle.orange)
                                Text(payment.isPaid ? "Paid" : "Unpaid")
                                    .font(.caption)
                                    .foregroundStyle(TMStyle.muted)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 950)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(TMStyle.canvas)
    }
}

private struct MonthlyIncome: Identifiable {
    let date: Date
    let amount: Double
    var id: Date { date }
}
