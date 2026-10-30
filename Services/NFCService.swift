import Foundation
import Combine
import CoreNFC

/// Reads an NDEF tag on supported physical iPhones. The tag should contain a text
/// record identifying the class/session; the decoded payload is returned to the UI.
@MainActor
final class NFCService: NSObject, ObservableObject, @preconcurrency NFCNDEFReaderSessionDelegate {
    @Published private(set) var isScanning = false
    private var session: NFCNDEFReaderSession?
    private var completion: ((Result<String, Error>) -> Void)?

    var isAvailable: Bool { NFCNDEFReaderSession.readingAvailable }

    func startScanning(completion: @escaping (Result<String, Error>) -> Void) {
        guard isAvailable else {
            completion(.failure(NFCServiceError.unavailable)); return
        }
        self.completion = completion
        isScanning = true
        let reader = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: true)
        reader.alertMessage = "Hold your iPhone near the TutorMate class NFC tag."
        session = reader
        reader.begin()
    }

    func cancelScanning() {
        session?.invalidate()
        session = nil
        isScanning = false
        completion?(.failure(NFCServiceError.cancelled))
        completion = nil
    }

    nonisolated static func decodeTextRecord(_ record: NFCNDEFPayload) -> String? {
        guard record.typeNameFormat == .nfcWellKnown,
              String(data: record.type, encoding: .utf8) == "T",
              let status = record.payload.first else { return nil }
        let languageLength = Int(status & 0x3F)
        let isUTF16 = (status & 0x80) != 0
        let start = 1 + languageLength
        guard record.payload.count > start else { return nil }
        return String(data: record.payload.dropFirst(start), encoding: isUTF16 ? .utf16 : .utf8)
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        Task { @MainActor in
            self.isScanning = false
            if let nfcError = error as? NFCReaderError, nfcError.code == .readerSessionInvalidationErrorUserCanceled {
                self.completion?(.failure(NFCServiceError.cancelled))
            } else if error.localizedDescription.contains("Session invalidated") == false {
                self.completion?(.failure(error))
            }
            self.completion = nil
            self.session = nil
        }
    }

    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        let payload = messages.flatMap(\.records).compactMap(Self.decodeTextRecord).first
        Task { @MainActor in
            self.isScanning = false
            if let payload, !payload.isEmpty { self.completion?(.success(payload)) }
            else { self.completion?(.failure(NFCServiceError.emptyTag)) }
            self.completion = nil
            self.session = nil
        }
    }

}

enum NFCServiceError: LocalizedError {
    case unavailable, cancelled, emptyTag, notNDEF
    var errorDescription: String? {
        switch self {
        case .unavailable: return "NFC reading is unavailable on this device. Use a supported physical iPhone."
        case .cancelled: return "NFC scan was cancelled."
        case .emptyTag: return "The NFC tag did not contain readable text."
        case .notNDEF: return "This tag is not formatted as an NDEF tag."
        }
    }
}

