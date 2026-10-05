import Foundation

struct DeleteCustomGameUseCase {
    let customGameRepo: any CustomGameRepository

    /// Past sessions keep their own rules snapshot, so deleting a game never changes history.
    func execute(id: String) async throws {
        try await customGameRepo.delete(id: id)
    }
}
