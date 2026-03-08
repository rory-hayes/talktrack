import Foundation
import Combine

@MainActor
final class Dependencies: ObservableObject {
    let authService: AuthService
    let telemetry: TelemetryService
    let localPracticeStore: LocalPracticeStore
    let favoriteScenarioStore: FavoriteScenarioStore
    let savedAnswerStore: SavedAnswerStore
    let scenarioRepository: ScenarioRepository
    let recorder: AudioRecorderService
    let audioPlayer: AudioPlaybackService
    let uploader: StorageUploadService
    let sessionService: PracticeSessionService
    lazy var progressService = ProgressService(localStore: localPracticeStore)
    let entitlementService: EntitlementService
    let userProfileService: UserProfileService
    let subscriptionService: SubscriptionService

    private var cancellables: Set<AnyCancellable> = []

    init() {
        FirebaseEmulatorConfig.configureIfNeeded()

        authService = AuthService()
        telemetry = TelemetryService.shared
        localPracticeStore = LocalPracticeStore()
        favoriteScenarioStore = FavoriteScenarioStore()
        savedAnswerStore = SavedAnswerStore()
        scenarioRepository = ScenarioRepository()
        recorder = AudioRecorderService()
        audioPlayer = AudioPlaybackService()
        uploader = StorageUploadService()
        sessionService = PracticeSessionService()
        entitlementService = EntitlementService()
        userProfileService = UserProfileService()
        subscriptionService = SubscriptionService()

        authService.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
