import Foundation
import CoreData
import CoreLocation

@MainActor
class StorageService: ObservableObject {
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
    
    private var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    private init() {
        loadAllRuns()
        detectUnfinishedRun()
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
                loadAllRuns()
            } catch {
                print("Failed to save context: \(error)")
            }
        }
    }
    
    func startNewRun(at location: CLLocation) -> RunEntity {
        let run = RunEntity(context: context)
        run.id = UUID()
        run.startedAt = Date()
        run.startLat = location.coordinate.latitude
        run.startLng = location.coordinate.longitude
        run.endRadius = 0.0
        run.finishConsecutive = 0
        
        currentRun = run
        save()
        
        print("Started new run: \(run.id?.uuidString ?? "unknown")")
        return run
    }
    
    func finishCurrentRun(endRadius: Double = 0.0, finishConsecutive: Int32 = 0) {
        guard let run = currentRun else { return }
        
        run.endedAt = Date()
        run.endRadius = endRadius
        run.finishConsecutive = finishConsecutive
        
        currentRun = nil
        save()
        
        print("Finished run: \(run.id?.uuidString ?? "unknown")")
    }
    
    func addTrackPoint(to run: RunEntity, location: CLLocation) {
        let trackPoint = TrackPointEntity(context: context)
        trackPoint.runId = run.id
        trackPoint.ts = location.timestamp
        trackPoint.lat = location.coordinate.latitude
        trackPoint.lng = location.coordinate.longitude
        trackPoint.accuracy = location.horizontalAccuracy
        trackPoint.speed = location.speed >= 0 ? NSNumber(value: location.speed) : nil
        trackPoint.heading = location.course >= 0 ? NSNumber(value: location.course) : nil
        trackPoint.run = run
        
        save()
        
        print("Added track point to run \(run.id?.uuidString ?? "unknown"): lat=\(trackPoint.lat), lng=\(trackPoint.lng)")
    }
    
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
            let unfinishedRuns = try context.fetch(request)
            if let unfinishedRun = unfinishedRuns.first {
                currentRun = unfinishedRun
                print("Detected unfinished run: \(unfinishedRun.id?.uuidString ?? "unknown"), started at \(unfinishedRun.startedAt ?? Date())")
            }
        } catch {
            print("Failed to detect unfinished run: \(error)")
        }
    }
    
    func getTrackPoints(for run: RunEntity) -> [TrackPointEntity] {
        let request: NSFetchRequest<TrackPointEntity> = TrackPointEntity.fetchRequest()
        request.predicate = NSPredicate(format: "runId == %@", run.id! as CVarArg)
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