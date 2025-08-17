import CoreLocation

final class AutoFinishJudge {
    // Params
    private let startCoord: CLLocationCoordinate2D
    private let endRadius: CLLocationDistance
    private let requiredInsideConsecutive: Int

    // Arming params
    private let requireExitBeforeFinish: Bool       // 一度外へ出ないと終了カウント開始しない
    private let armDistanceMeters: CLLocationDistance? // これ以上離れたらarmedにする（任意）
    private let minElapsedSeconds: TimeInterval?    // この秒数経過でarmed（任意）

    // State
    private(set) var consecutiveHits: Int = 0
    private(set) var shouldFinish: Bool = false
    private var startedAt: Date
    private var isArmed: Bool = false
    private var outsideConsecutive: Int = 0
    private let outsideNeededToArm: Int = 1         // 何サンプル連続 outside で armed にするか（1で十分）
    
    // 便宜上公開（デバッグ/テスト用）
    var startLocation: CLLocation {
        CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
    }

    init(
        startLatitude: Double,
        startLongitude: Double,
        endRadius: CLLocationDistance,
        requiredConsecutiveHits: Int,
        requireExitBeforeFinish: Bool = true,
        armDistanceMeters: CLLocationDistance? = 50,   // 50m 離れたら armed
        minElapsedSeconds: TimeInterval? = 60          // 60秒経過で armed
    ) {
        self.startCoord = .init(latitude: startLatitude, longitude: startLongitude)
        self.endRadius = endRadius
        self.requiredInsideConsecutive = max(1, requiredConsecutiveHits)
        self.requireExitBeforeFinish = requireExitBeforeFinish
        self.armDistanceMeters = armDistanceMeters
        self.minElapsedSeconds = minElapsedSeconds
        self.startedAt = Date()
    }

    func reset() {
        consecutiveHits = 0
        shouldFinish = false
        isArmed = false
        outsideConsecutive = 0
        startedAt = Date()
    }

    func processLocationUpdate(_ loc: CLLocation) {
        guard !shouldFinish else { return }

        let dist = loc.distance(from: startLocation)
        let now = Date()

        // --- Arming logic ---
        if !isArmed {
            var arm = false

            // 条件1: 一度 outside を踏む（requireExitBeforeFinish=true の場合）
            if requireExitBeforeFinish {
                if dist > endRadius {
                    outsideConsecutive += 1
                    if outsideConsecutive >= outsideNeededToArm { arm = true }
                } else {
                    outsideConsecutive = 0
                }
            }

            // 条件2: 一定距離離れたら armed
            if let armD = armDistanceMeters, dist >= armD {
                arm = true
            }

            // 条件3: 一定時間経過で armed
            if let minSec = minElapsedSeconds, now.timeIntervalSince(startedAt) >= minSec {
                arm = true
            }

            if arm {
                isArmed = true
                consecutiveHits = 0 // armed になった時点で inside 連続はリセット
                // print("[AutoFinish] armed = true")
            } else {
                // まだ armed でない間は終了カウントしない
                return
            }
        }

        // --- Finish counting ---
        if dist <= endRadius {
            consecutiveHits += 1
            // print("[AutoFinish] inside \(consecutiveHits)/\(requiredInsideConsecutive)")
            if consecutiveHits >= requiredInsideConsecutive {
                shouldFinish = true
            }
        } else {
            // outside に出たら inside 連続はリセット
            consecutiveHits = 0
        }
    }
}
