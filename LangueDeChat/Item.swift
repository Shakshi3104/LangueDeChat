//
//  Item.swift
//  LangueDeChat
//
//  Created by Mac mini M2 Pro on 2026/06/16.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
