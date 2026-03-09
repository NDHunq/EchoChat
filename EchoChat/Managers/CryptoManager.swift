//
//  CryptoManager.swift
//  EchoChat
//
//  Provides AES-GCM symmetric encryption / decryption for chat messages.
//
//  ⚠️  Demo note:
//  A single pre-shared SymmetricKey is used here so every simulator that
//  runs the same binary can encrypt and decrypt each other's messages
//  without a key-exchange round-trip over the mock WebSocket server.
//
//  In a production app you would:
//    1. Generate a Curve25519 key-pair per user (CryptoKit.Curve25519.KeyAgreement).
//    2. Exchange public keys via the signalling server.
//    3. Derive a shared secret with HKDF, then use that as the AES-GCM key.
//  This follows the Signal Protocol / X3DH pattern and gives true E2EE.
//

import Foundation
import CryptoKit

final class CryptoManager {

    // MARK: - Singleton

    static let shared = CryptoManager()
    private init() {}

    // MARK: - Pre-Shared Symmetric Key (256-bit AES-GCM)

    /// All clients that share this binary also share this key, which is
    /// sufficient for a closed-group local demo.
    /// TODO: Replace with a per-session key derived from Curve25519 key agreement.
    static let sharedSymmetricKey = SymmetricKey(data: Data(
        // Deterministic 32-byte seed so every simulator build uses the same key.
        // Generated once with: SymmetricKey(size: .bits256).withUnsafeBytes { Array($0) }
        bytes: [
            0x4A, 0x7F, 0x3C, 0xB2, 0xE1, 0x95, 0xDA, 0x08,
            0x6E, 0xF4, 0x21, 0xBC, 0x73, 0x5A, 0x9D, 0x0F,
            0xC8, 0x46, 0x12, 0xEA, 0x87, 0x3B, 0xD5, 0x60,
            0x1C, 0xAF, 0x99, 0x2E, 0x54, 0x78, 0xB1, 0x3D
        ]
    ))

    // MARK: - Encrypt

    /// Encrypts a plain-text string using AES-GCM.
    /// - Returns: A Base64-encoded string of the combined sealed-box
    ///   (nonce + ciphertext + tag), or `nil` if encryption fails.
    func encrypt(message: String) -> String? {
        guard let data = message.data(using: .utf8) else {
            print("[CryptoManager] Encrypt: failed to convert string to Data")
            return nil
        }

        do {
            let sealedBox = try AES.GCM.seal(data, using: CryptoManager.sharedSymmetricKey)
            guard let combined = sealedBox.combined else {
                print("[CryptoManager] Encrypt: sealedBox.combined is nil")
                return nil
            }
            return combined.base64EncodedString()
        } catch {
            print("[CryptoManager] Encrypt error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Decrypt

    /// Decrypts a Base64-encoded AES-GCM sealed-box back to a plain-text string.
    /// - Returns: The decrypted plain-text string, or `nil` if decryption fails.
    func decrypt(base64String: String) -> String? {
        guard let data = Data(base64Encoded: base64String) else {
            print("[CryptoManager] Decrypt: invalid Base64 input")
            return nil
        }

        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: CryptoManager.sharedSymmetricKey)
            guard let plainText = String(data: decryptedData, encoding: .utf8) else {
                print("[CryptoManager] Decrypt: failed to convert Data to String")
                return nil
            }
            return plainText
        } catch {
            print("[CryptoManager] Decrypt error: \(error.localizedDescription)")
            return nil
        }
    }
}
