import Foundation
import Combine

@MainActor
final class Dependencies: ObservableObject {
    let authService = AuthService()
    let telemetry = TelemetryService.shared
    let localPracticeStore = LocalPracticeStore()
    let favoriteScenarioStore = FavoriteScenarioStore()
    let savedAnswerStore = SavedAnswerStore()
    let scenarioRepository = ScenarioRepository()
    let recorder = AudioRecorderService()
    let audioPlayer = AudioPlaybackService()
    let uploader = StorageUploadService()
    let sessionService = PracticeSessionService()
    lazy var progressService = ProgressService(localStore: localPracticeStore)
    let entitlementService = EntitlementService()
    let userProfileService = UserProfileService()
    let subscriptionService = SubscriptionService()

    private var cancellables: Set<AnyCancellable> = []

    init() {
        authService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
