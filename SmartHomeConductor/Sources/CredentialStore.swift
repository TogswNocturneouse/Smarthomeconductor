import Foundation
import Security

enum CredentialStoreError: LocalizedError {
    case invalidReference
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidReference:
            "Credential references cannot be empty."
        case let .unexpectedStatus(status):
            "Keychain operation failed with status \(status)."
        }
    }
}

protocol IntegrationCredentialStore: Sendable {
    func save(_ secret: Data, reference: String) throws
    func read(reference: String) throws -> Data?
    func delete(reference: String) throws
}

struct KeychainCredentialStore: IntegrationCredentialStore {
    let service: String

    init(service: String = "app.conductor.smart.home.integrations") {
        self.service = service
    }

    func save(_ secret: Data, reference: String) throws {
        let account = try validated(reference)
        let query = baseQuery(account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: secret,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insert = query
            attributes.forEach { insert[$0.key] = $0.value }
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw CredentialStoreError.unexpectedStatus(insertStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw CredentialStoreError.unexpectedStatus(updateStatus)
        }
    }

    func read(reference: String) throws -> Data? {
        let account = try validated(reference)
        var query = baseQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
        return data
    }

    func delete(reference: String) throws {
        let account = try validated(reference)
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unexpectedStatus(status)
        }
    }

    private func validated(_ reference: String) throws -> String {
        let value = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw CredentialStoreError.invalidReference
        }
        return value
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false
        ]
    }
}

final class InMemoryCredentialStore: IntegrationCredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func save(_ secret: Data, reference: String) throws {
        let key = try validated(reference)
        lock.withLock {
            values[key] = secret
        }
    }

    func read(reference: String) throws -> Data? {
        let key = try validated(reference)
        return lock.withLock {
            values[key]
        }
    }

    func delete(reference: String) throws {
        let key = try validated(reference)
        _ = lock.withLock {
            values.removeValue(forKey: key)
        }
    }

    private func validated(_ reference: String) throws -> String {
        let value = reference.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw CredentialStoreError.invalidReference
        }
        return value
    }
}
