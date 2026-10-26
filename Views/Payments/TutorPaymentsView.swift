import SwiftUI

struct TutorPaymentsView: View {
    @EnvironmentObject private var app: AppController
    @State private var showAdd = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Student payments", subtitle: "Manage tuition fees, payments and outstanding balances.")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Collected", value: "$\(Int(app.collectedIncome))", detail: "Payments received", icon: "checkmark.circle.fill", tint: TMStyle.green)
                    MetricTile(title: "Outstanding", value: "$\(Int(app.outstandingIncome))", detail: "Awaiting payment", icon: "clock.fill", tint: TMStyle.orange)
                    MetricTile(title: "Records", value: "\(app.payments.count)", detail: "Payment records", icon: "creditcard.fill")
                }
                HStack {
                    Text("Payment history").font(.headline)
                    Spacer()
                    Button { showAdd = true } label: { Label("Add payment", systemImage: "plus") }.buttonStyle(.borderedProminent)
                }
                ForEach(app.payments) { payment in
                    TMCard {
                        HStack(spacing: 12) {
                            Image(systemName: "creditcard.fill").foregroundStyle(TMStyle.blue).frame(width: 42, height: 42).background(TMStyle.blueSoft, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(payment.studentName).font(.headline).foregroundStyle(TMStyle.ink)
                                Text(payment.description).font(.caption).foregroundStyle(TMStyle.muted)
                                Text(payment.date.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(TMStyle.muted)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 7) {
                                Text("$\(Int(payment.amount))").font(.headline).foregroundStyle(TMStyle.ink)
                                if payment.isPaid { StatusPill(text: "Paid") }
                                else { Button("Mark paid") { app.markPaid(payment) }.font(.caption.weight(.semibold)).buttonStyle(.bordered) }
                            }
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 950).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
        .sheet(isPresented: $showAdd) { AddPaymentSheet() }
    }
}
private struct AddPaymentSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = "120"
    @State private var description = "Monthly tuition"
    var body: some View {
        NavigationStack {
            Form {
                TextField("Student name", text: $name)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                TextField("Description", text: $description)
            }.navigationTitle("Add payment")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") {
                        guard let value = Double(amount), value > 0 else { return }
                        app.addPayment(name: name.isEmpty ? "Demo Student" : name, amount: value, description: description)
                        dismiss()
                    } }
                }
        }
    }
}
