import SwiftUI

struct TutorPaymentsView: View {
    @EnvironmentObject private var app: AppController
    @State private var showAdd = false
    @State private var editingPayment: Payment?
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

                if app.isLoadingPayments {
                    ProgressView("Loading saved payments…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 36)
                } else if app.payments.isEmpty {
                    ContentUnavailableView(
                        "No saved payments yet",
                        systemImage: "creditcard",
                        description: Text("Add a payment to save it to your TutorMate account.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
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
                                    if payment.isPaid {
                                        Button { var changed = payment; changed.isPaid = false; Task { _ = await app.updatePayment(changed) } } label: { StatusPill(text: "Paid · mark unpaid", color: TMStyle.green) }
                                    } else {
                                        Button("Mark paid") {
                                            app.markPaid(payment)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .buttonStyle(.bordered)
                                        .disabled(app.updatingPaymentIDs.contains(payment.id))
                                    }
                                    Button("Edit") { editingPayment = payment }.font(.caption)
                                }
                            }
                        }
                    }
                }
            }.padding(20).frame(maxWidth: 950).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
        .sheet(isPresented: $showAdd) { AddPaymentSheet() }
        .sheet(item: $editingPayment) { AddPaymentSheet(existing: $0) }
    }
}
private struct AddPaymentSheet: View {
    @EnvironmentObject private var app: AppController
    @Environment(\.dismiss) private var dismiss
    var existing: Payment? = nil
    @State private var name = ""
    @State private var amount = "120"
    @State private var description = "Monthly tuition"
    @State private var isSaving = false
    @State private var errorMessage = ""

    init(existing: Payment? = nil) {
        self.existing = existing
        _name = State(initialValue: existing?.studentName ?? "")
        _amount = State(initialValue: existing.map { String($0.amount) } ?? "120")
        _description = State(initialValue: existing?.description ?? "Monthly tuition")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Student name", text: $name)
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                TextField("Description", text: $description)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }.navigationTitle(existing == nil ? "Add payment" : "Edit payment")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .disabled(isSaving)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(isSaving ? "Saving..." : "Save") {
                            savePayment()
                        }
                        .disabled(isSaving)
                    }
                }
        }
    }

    private func savePayment() {
        errorMessage = ""

        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            errorMessage = "Please enter the student's name."
            return
        }

        guard let value = Double(amount), value > 0 else {
            errorMessage = "Please enter a valid amount."
            return
        }

        guard !cleanDescription.isEmpty else {
            errorMessage = "Please enter a payment description."
            return
        }

        isSaving = true

        Task { @MainActor in
            let saved: Bool
            if var existing {
                existing.studentName = cleanName; existing.amount = value; existing.description = cleanDescription
                saved = await app.updatePayment(existing)
            } else {
                saved = await app.addPayment(name: cleanName, amount: value, description: cleanDescription)
            }

            isSaving = false

            if saved {
                dismiss()
            } else {
                errorMessage = app.toastMessage ?? "Could not save payment. Your details are still here."
            }
        }
    }
}
