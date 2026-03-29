//
//  Item.swift
//  FUELBREAK
//
//  Created by alew on 3/28/26.
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
