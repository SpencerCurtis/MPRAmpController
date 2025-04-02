//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/28/20.
//

import Foundation
import Fluent
import FluentSQLiteDriver
import Vapor

final class ZoneName: Model, Content {
    
    static let schema: String = "zoneNames"
    
    @ID
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "zoneID")
    var zoneID: Int
    
    init() {}
    
    init(id: UUID? = nil, name: String, zoneID: Int) {
        self.id = id
        self.name = name
        self.zoneID = zoneID
    }
}
