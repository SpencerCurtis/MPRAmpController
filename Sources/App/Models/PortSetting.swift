//
//  File.swift
//  
//
//  Created by Spencer Curtis on 7/1/20.
//

import Foundation
import SwiftSerial

struct PortSettings {
    var path: String
    var receiveRate: BaudRate
    var transmitRate: BaudRate
    var minimumBytesToRead: Int
}

enum SettingIdentifier: String {
    case path
    case receiveRate
    case transmitRate
}
