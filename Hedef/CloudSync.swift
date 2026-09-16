import CloudKit
import Foundation
import CryptoKit

enum CloudSyncStatus: Equatable {
    case unavailable
    case ready
    case syncing
    case failed(String)
}

enum CloudSyncFailure: LocalizedError {
    case iCloudUnavailable
    case repeatedConflict
    case unreadableCloudData
    var errorDescription: String? {
        switch self {
        case .iCloudUnavailable: return "iCloud hesabı bu cihazda kullanılmıyor."
        case .repeatedConflict: return "Eşitleme çakıştı; biraz sonra yeniden denenecek."
        case .unreadableCloudData: return "iCloud kaydı okunamadı; veri korunması için eşitleme durduruldu."
        }
    }
}

actor CloudSyncService {
    static let shared = CloudSyncService()
    private let container = CKContainer.default()

    private func recordID(for userID: String) -> CKRecord.ID {
        let digest = SHA256.hash(data: Data(userID.utf8)).map { String(format: "%02x", $0) }.joined()
        return CKRecord.ID(recordName: "hedef-state-v1-\(digest)")
    }

    func available() async -> Bool {
        (try? await container.accountStatus()) == .available
    }

    func merge(local: AppState, remote: AppState) -> AppState {
        var merged = local
        merged.deletedGoalIDs.merge(remote.deletedGoalIDs) { max($0, $1) }
        merged.deletedEntryIDs.merge(remote.deletedEntryIDs) { max($0, $1) }

        var goals: [UUID: Goal] = [:]
        for goal in local.goals + remote.goals {
            if let old = goals[goal.id], old.updatedAt >= goal.updatedAt { continue }
            goals[goal.id] = goal
        }
        merged.goals = goals.values.filter {
            (merged.deletedGoalIDs[$0.id.uuidString] ?? .distantPast) < $0.updatedAt
        }.sorted { $0.createdAt < $1.createdAt }

        var entries: [UUID: MoneyEntry] = [:]
        for entry in local.entries + remote.entries {
            if let old = entries[entry.id], old.updatedAt >= entry.updatedAt { continue }
            entries[entry.id] = entry
        }
        merged.entries = entries.values.filter { entry in
            (merged.deletedEntryIDs[entry.id.uuidString] ?? .distantPast) < entry.updatedAt &&
            (entry.goalID == nil || merged.goals.contains(where: { $0.id == entry.goalID }))
        }.sorted { $0.date > $1.date }

        for index in merged.goals.indices {
            let goalID = merged.goals[index].id
            merged.goals[index].savedMinor = GoalMath.savingsBalance(entries: merged.entries, goalID: goalID)
        }

        if remote.budget.updatedAt > local.budget.updatedAt { merged.budget = remote.budget }
        if merged.selectedGoalID.flatMap({ id in merged.goals.first(where: { $0.id == id }) }) == nil {
            merged.selectedGoalID = merged.goals.first?.id
        }
        merged.updatedAt = max(local.updatedAt, remote.updatedAt)
        return merged
    }

    func sync(local: AppState, userID: String) async throws -> AppState {
        guard await available() else { throw CloudSyncFailure.iCloudUnavailable }
        let recordID = recordID(for: userID)
        var candidate = local
        for _ in 0..<3 {
            var record: CKRecord
            do {
                record = try await container.privateCloudDatabase.record(for: recordID)
                let hasStoredState = record["stateAsset"] != nil || record["state"] != nil
                let data = (record["stateAsset"] as? CKAsset)?.fileURL.flatMap { try? Data(contentsOf: $0) }
                    ?? (record["state"] as? Data)
                if let data {
                    guard let remote = try? JSONDecoder().decode(AppState.self, from: data) else {
                        throw CloudSyncFailure.unreadableCloudData
                    }
                    candidate = merge(local: candidate, remote: remote)
                } else if hasStoredState {
                    throw CloudSyncFailure.unreadableCloudData
                }
            } catch let error as CKError where error.code == .unknownItem {
                record = CKRecord(recordType: "HedefState", recordID: recordID)
            } catch {
                throw error
            }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("hedef-sync-\(UUID().uuidString).json")
            try JSONEncoder().encode(candidate).write(to: tempURL, options: .atomic)
            record["stateAsset"] = CKAsset(fileURL: tempURL)
            do {
                _ = try await container.privateCloudDatabase.save(record)
                try? FileManager.default.removeItem(at: tempURL)
                return candidate
            } catch let error as CKError where error.code == .serverRecordChanged {
                try? FileManager.default.removeItem(at: tempURL)
                continue
            } catch {
                try? FileManager.default.removeItem(at: tempURL)
                throw error
            }
        }
        throw CloudSyncFailure.repeatedConflict
    }
}
