import SwiftData
import Foundation

@Model
final class CustomGameModel {
    @Attribute(.unique) var id: String
    var name: String
    var symbol: String
    var rulesJSON: Data
    var createdAt: Date

    init(id: String, name: String, symbol: String, rules: HouseGameRules) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.rulesJSON = (try? JSONEncoder().encode(rules)) ?? Data()
        self.createdAt = .now
    }

    func update(from game: HouseGame) {
        name = game.name
        symbol = game.symbol
        rulesJSON = (try? JSONEncoder().encode(game.rules)) ?? rulesJSON
    }

    func toDomain() -> HouseGame {
        let rules = (try? JSONDecoder().decode(HouseGameRules.self, from: rulesJSON)) ?? HouseGameRules()
        return HouseGame(id: id, name: name, symbol: symbol, category: nil, rules: rules)
    }
}
