//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/28/20.
//

import Foundation
import Fluent
import FluentSQLiteDriver

final class ZoneName: Model {
    
    static let schema: String = "zoneNames"
    
    @ID
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "zoneID")
    var zoneID: Int
    
}
