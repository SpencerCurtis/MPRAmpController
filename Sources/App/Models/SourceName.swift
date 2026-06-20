//
//  SourceName.swift
//
//
//  Friendly names for the six inputs/sources, so a UI can show "Apple TV"
//  instead of "3".
//

import Foundation
import Fluent
import Vapor

final class SourceName: Model {
    static let schema = "sourceNames"

    @ID var id: UUID?
    @Field(key: "sourceID") var sourceID: Int
    @Field(key: "name") var name: String

    init() {}

    init(id: UUID? = nil, sourceID: Int, name: String) {
        self.id = id
        self.sourceID = sourceID
        self.name = name
    }
}

struct SourceDTO: Content {
    let id: Int
    let name: String
}

enum SourceCatalog {
    static let ids = 1...6

    /// All six sources, filling `Source N` for any without a saved name.
    static func merged(savedNames: [Int: String]) -> [SourceDTO] {
        ids.map { SourceDTO(id: $0, name: savedNames[$0] ?? "Source \($0)") }
    }
}
