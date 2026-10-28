import Foundation

@MainActor
final class PaymentController {
    func add(name: String, amount: Double, description: String, in app: AppController) async -> Bool {
        await app.addPayment(name: name, amount: amount, description: description)
    }

    func markPaid(_ payment: Payment, in app: AppController) {
        app.markPaid(payment)
    }
}
