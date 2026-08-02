import Foundation

struct Vote: Codable, Identifiable, Hashable {
    let id: String?
    let userId: String?
    let vote: VoteValue

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case vote
    }
}

struct VotesResponse: Codable {
    let vote: Vote?
    let votes: [Vote]?
}

struct SubmitVoteRequest: Codable {
    let vote: VoteValue
    
    enum CodingKeys: String, CodingKey {
        case vote
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch vote {
        case .up: try container.encode(1, forKey: .vote)
        case .down: try container.encode(-1, forKey: .vote)
        case .remove: try container.encode(0, forKey: .vote)
        }
    }
}

