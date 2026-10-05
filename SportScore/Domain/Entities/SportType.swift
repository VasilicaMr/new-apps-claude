import Foundation

enum SportType: String, CaseIterable, Identifiable, Codable, Sendable {

    // Precision & Aiming
    case darts
    case archery
    case sportShooting
    case axeThrowing
    case knifeThrowing
    case slingshot
    case blowgun

    // Cue Sports
    case pool
    case snooker
    case caroms
    case cushionCaroms

    // Bowling
    case bowlingTenPin
    case bowlingNinePin
    case bowlingCandlepin
    case bowlingDuckpin
    case bocce
    case petanque
    case boules
    case lawnBowls
    case skittles

    // Racket
    case tableTennis
    case badminton
    case squash
    case racquetball
    case tennis
    case padel
    case pickleball

    // Card & Tile
    case dominoes
    case mahjong
    case cribbage
    case pokerTournament

    // Mind Sports
    case chess
    case checkers
    case go
    case backgammon
    case scrabble

    // Ice & Outdoor
    case curling
    case horseshoes
    case cornhole
    case ringToss
    case discGolf
    case kubb
    case croquet
    case shuffleboard

    // Pub / Parlour
    case airHockey
    case foosball
    case pinball
    case armWrestling

    // Home & custom games (rules come from the session's HouseGame config)
    case houseGame

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .darts:           return "Darts"
        case .archery:         return "Archery"
        case .sportShooting:   return "Sport Shooting"
        case .axeThrowing:     return "Axe Throwing"
        case .knifeThrowing:   return "Knife Throwing"
        case .slingshot:       return "Slingshot"
        case .blowgun:         return "Blowgun"
        case .pool:            return "Pool / Billiards"
        case .snooker:         return "Snooker"
        case .caroms:          return "Carom Billiards"
        case .cushionCaroms:   return "Cushion Caroms"
        case .bowlingTenPin:   return "Ten-Pin Bowling"
        case .bowlingNinePin:  return "Nine-Pin Bowling"
        case .bowlingCandlepin: return "Candlepin Bowling"
        case .bowlingDuckpin:  return "Duckpin Bowling"
        case .bocce:           return "Bocce Ball"
        case .petanque:        return "Pétanque"
        case .boules:          return "Boules"
        case .lawnBowls:       return "Lawn Bowls"
        case .skittles:        return "Skittles"
        case .tableTennis:     return "Table Tennis"
        case .badminton:       return "Badminton"
        case .squash:          return "Squash"
        case .racquetball:     return "Racquetball"
        case .tennis:          return "Tennis"
        case .padel:           return "Padel"
        case .pickleball:      return "Pickleball"
        case .dominoes:        return "Dominoes"
        case .mahjong:         return "Mahjong"
        case .cribbage:        return "Cribbage"
        case .pokerTournament: return "Poker (Tournament)"
        case .chess:           return "Chess"
        case .checkers:        return "Checkers"
        case .go:              return "Go"
        case .backgammon:      return "Backgammon"
        case .scrabble:        return "Scrabble"
        case .curling:         return "Curling"
        case .horseshoes:      return "Horseshoes"
        case .cornhole:        return "Cornhole"
        case .ringToss:        return "Ring Toss"
        case .discGolf:        return "Disc Golf"
        case .kubb:            return "Kubb"
        case .croquet:         return "Croquet"
        case .shuffleboard:    return "Shuffleboard"
        case .airHockey:       return "Air Hockey"
        case .foosball:        return "Foosball"
        case .pinball:         return "Pinball"
        case .armWrestling:    return "Arm Wrestling"
        case .houseGame:       return "Home Game"
        }
    }

    var systemImageName: String {
        switch self {
        case .darts:           return "target"
        case .archery:         return "arrow.up.right"
        case .sportShooting:   return "scope"
        case .axeThrowing:     return "hammer"
        case .knifeThrowing:   return "scissors"
        case .slingshot:       return "arrow.trianglehead.branch"
        case .blowgun:         return "wind"
        case .pool:            return "circle.grid.3x3"
        case .snooker:         return "circle.grid.3x3.fill"
        case .caroms:          return "circle.dotted"
        case .cushionCaroms:   return "circle.dashed"
        case .bowlingTenPin:   return "figure.bowling"
        case .bowlingNinePin:  return "figure.bowling"
        case .bowlingCandlepin: return "figure.bowling"
        case .bowlingDuckpin:  return "figure.bowling"
        case .bocce:           return "circle.fill"
        case .petanque:        return "circle.fill"
        case .boules:          return "circle.fill"
        case .lawnBowls:       return "circle.fill"
        case .skittles:        return "figure.bowling"
        case .tableTennis:     return "figure.table.tennis"
        case .badminton:       return "figure.badminton"
        case .squash:          return "figure.squash"
        case .racquetball:     return "figure.racquetball"
        case .tennis:          return "figure.tennis"
        case .padel:           return "tennisball"
        case .pickleball:      return "tennisball.fill"
        case .dominoes:        return "rectangle.grid.2x2"
        case .mahjong:         return "square.grid.3x3"
        case .cribbage:        return "rectangle.stack"
        case .pokerTournament: return "suit.spade.fill"
        case .chess:           return "crown"
        case .checkers:        return "checkerboard.rectangle"
        case .go:              return "circle.grid.cross"
        case .backgammon:      return "dice"
        case .scrabble:        return "text.word.spacing"
        case .curling:         return "circle.hexagongrid"
        case .horseshoes:      return "c.circle"
        case .cornhole:        return "oval.fill"
        case .ringToss:        return "ring"
        case .discGolf:        return "figure.disc.sports"
        case .kubb:            return "rectangle.split.3x1"
        case .croquet:         return "figure.croquet"
        case .shuffleboard:    return "arrow.right.circle"
        case .airHockey:       return "hockey.puck"
        case .foosball:        return "figure.soccer"
        case .pinball:         return "circle.grid.cross.fill"
        case .armWrestling:    return "figure.strengthtraining.traditional"
        case .houseGame:       return "star.fill"
        }
    }

    var category: SportCategory {
        switch self {
        case .darts, .archery, .sportShooting, .axeThrowing,
             .knifeThrowing, .slingshot, .blowgun:
            return .precisionAiming
        case .pool, .snooker, .caroms, .cushionCaroms:
            return .cueSports
        case .bowlingTenPin, .bowlingNinePin, .bowlingCandlepin, .bowlingDuckpin,
             .bocce, .petanque, .boules, .lawnBowls, .skittles:
            return .bowling
        case .tableTennis, .badminton, .squash, .racquetball,
             .tennis, .padel, .pickleball:
            return .racket
        case .dominoes, .mahjong, .cribbage, .pokerTournament:
            return .cardTile
        case .chess, .checkers, .go, .backgammon, .scrabble:
            return .mindSports
        case .curling, .horseshoes, .cornhole, .ringToss,
             .discGolf, .kubb, .croquet, .shuffleboard:
            return .iceOutdoor
        case .airHockey, .foosball, .pinball, .armWrestling:
            return .pubParlour
        case .houseGame:
            return .cardTile
        }
    }

    var defaultVariants: [String] {
        switch self {
        case .darts:           return ["501", "301", "Cricket", "Around The Clock", "Shanghai"]
        case .pool:            return ["8-Ball", "9-Ball", "10-Ball", "Straight Pool", "One Pocket"]
        case .bowlingTenPin,
             .bowlingCandlepin,
             .bowlingDuckpin:  return ["Standard"]
        case .tennis:          return ["Best of 3", "Best of 5"]
        case .tableTennis:     return ["Best of 3", "Best of 5", "Best of 7"]
        case .squash:          return ["PAR", "HiHo"]
        case .dominoes:        return ["Draw", "Block", "Mexican Train", "All Fives"]
        case .mahjong:         return ["Chinese", "Japanese", "American"]
        case .chess:           return ["Standard", "Chess960"]
        case .checkers:        return ["8×8 Standard", "10×10 International", "12×12 Canadian"]
        case .go:              return ["9×9", "13×13", "19×19"]
        case .bocce, .petanque, .boules: return ["Standard"]
        case .croquet:         return ["Association", "Golf Croquet"]
        case .pickleball:      return ["Singles", "Doubles"]
        case .caroms:          return ["Straight Carom"]
        case .cushionCaroms:   return ["3-Cushion"]
        case .pokerTournament: return ["Freezeout", "Rebuy", "Bounty"]
        default:               return ["Standard"]
        }
    }
}

enum SportCategory: String, CaseIterable, Identifiable, Sendable {
    case precisionAiming = "Precision & Aiming"
    case cueSports       = "Cue Sports"
    case bowling         = "Bowling"
    case racket          = "Racket"
    case cardTile        = "Card & Tile"
    case mindSports      = "Mind Sports"
    case iceOutdoor      = "Ice & Outdoor"
    case pubParlour      = "Pub & Parlour"

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .precisionAiming: return "target"
        case .cueSports:       return "circle.grid.3x3"
        case .bowling:         return "figure.bowling"
        case .racket:          return "figure.tennis"
        case .cardTile:        return "suit.spade.fill"
        case .mindSports:      return "crown"
        case .iceOutdoor:      return "snowflake"
        case .pubParlour:      return "mug"
        }
    }

    var sports: [SportType] {
        // Home games are listed from HouseGameCatalog, not as a sport.
        SportType.allCases.filter { $0.category == self && $0 != .houseGame }
    }
}
