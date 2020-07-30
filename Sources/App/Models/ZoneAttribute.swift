//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/1/20.
//

import Foundation

struct ZoneAttribute: Equatable {
    
    let zoneID: Int
    let identifier: ZoneAttributeIdentifier
    let name: String
    let minValue: Int
    let maxValue: Int
    var value: Int
}
