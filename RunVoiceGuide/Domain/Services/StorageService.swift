import Foundation
import CoreData
import CoreLocation

@MainActor
final class StorageService: ObservableObject {
    static let shared = StorageService()

    @Published var currentRun: RunEntity?
    @Published var allRuns: [RunEntity] = []

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "RunVoiceGuide")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    private var context: NSManagedObjectContext { persistentContainer.viewContext }

    private init() {
        loadAllRuns()
        detectUnfinishedRun()
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
            loadAllRuns()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    // MARK: - Run Lifecycle

    /// Start時に Run を作り、同時に「開始点 TrackPoint」を1件保存（空Run防止）
    func startNewRun(at location: CLLocation) {
        let run = RunEntity(context: context)
        run.id = UUID()
        run.startedAt = Date()
        run.startLat = location.coordinate.latitude
        run.startLng = location.coordinate.longitude
        run.endRadius = 0.0
        run.finishConsecutive = 0

        // 開始点を即保存
        let tp = TrackPointEntity(context: context)
        tp.runId = run.id
        tp.ts = run.startedAt
        tp.lat = location.coordinate.latitude
        tp.lng = location.coordinate.longitude
        tp.accuracy = location.horizontalAccuracy
        tp.speed = location.speed >= 0 ? NSNumber(value: location.speed) : nil
        tp.heading = location.course >= 0 ? NSNumber(value: location.course) : nil
        tp.run = run

        currentRun = run
        save()
        print("[Storage] Started new run: \(run.id?.uuidString ?? "unknown") with initial point")
    }

    func finishCurrentRun(endRadius: Double = 0.0, finishConsecutive: Int32 = 0) {
        guard let run = currentRun else { return }
        run.endedAt = Date()
        run.endRadius = endRadius
        run.finishConsecutive = finishConsecutive
        currentRun = nil
        save()
        print("[Storage] Finished run: \(run.id?.uuidString ?? "unknown")")
    }

    // MARK: - TrackPoints

    func addTrackPoint(to run: RunEntity, location: CLLocation) {
        let tp = TrackPointEntity(context: context)
        tp.runId = run.id
        tp.ts = location.timestamp
        tp.lat = location.coordinate.latitude
        tp.lng = location.coordinate.longitude
        tp.accuracy = location.horizontalAccuracy
        tp.speed = location.speed >= 0 ? NSNumber(value: location.speed) : nil
        tp.heading = location.course >= 0 ? NSNumber(value: location.course) : nil
        tp.run = run

        save()
        print("[Storage] Append point run=\(run.id?.uuidString ?? "unknown") lat=\(tp.lat), lng=\(tp.lng)")
    }

    /// currentRun がある前提で append できるユーティリティ（使わなくてもOK）
    func appendTrackPoint(_ location: CLLocation) {
        guard let run = currentRun else { return }
        addTrackPoint(to: run, location: location)
    }

    // MARK: - Queries

    func loadAllRuns() {
        let request: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RunEntity.startedAt, ascending: false)]
        do {
            allRuns = try context.fetch(request)
        } catch {
            print("Failed to fetch runs: \(error)")
            allRuns = []
        }
    }

    private func detectUnfinishedRun() {
        let request: NSFetchRequest<RunEntity> = RunEntity.fetchRequest()
        request.predicate = NSPredicate(format: "endedAt == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RunEntity.startedAt, ascending: false)]
        request.fetchLimit = 1
        do {
            if let unfinished = try context.fetch(request).first {
                currentRun = unfinished
                print("[Storage] Detected unfinished run: \(unfinished.id?.uuidString ?? "unknown")")
            }
        } catch {
            print("Failed to detect unfinished run: \(error)")
        }
    }

    func getTrackPoints(for run: RunEntity) -> [TrackPointEntity] {
        guard let runId = run.id else {
            print("[StorageService] Cannot get track points: run.id is nil")
            return []
        }
        
        let request: NSFetchRequest<TrackPointEntity> = TrackPointEntity.fetchRequest()
        request.predicate = NSPredicate(format: "runId == %@", runId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TrackPointEntity.ts, ascending: true)]
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch track points: \(error)")
            return []
        }
    }

    func deleteRun(_ run: RunEntity) {
        context.delete(run)
        if currentRun?.id == run.id {
            currentRun = nil
        }
        save()
    }
}
