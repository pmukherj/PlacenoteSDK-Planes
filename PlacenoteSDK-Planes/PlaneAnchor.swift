//
//  PlaneAnchor.swift
//  PlacenoteSDK-Planes
//
//  Created by Prasenjit Mukherjee on 2018-01-29.
//  Copyright © 2018 Vertical AI. All rights reserved.
//

import Foundation
import UIKit
import os.log


class PlaneAnchor: NSObject, NSCoding {
  
  var planeX: Float
  var planeY: Float
  var planeZ: Float
  var width: Float
  var height: Float
  
  
  struct PropertyKey {
    static let planeX = "planeX"
    static let planeY = "planeY"
    static let planeZ = "planeZ"
    static let width = "width"
    static let height = "height"
  }
  
  static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
  static let ArchiveURL = DocumentsDirectory.appendingPathComponent("plane")

  init?(xIn: Float, yIn: Float, zIn: Float, height: Float, width: Float) {
    // Initialize stored properties.
    self.planeX = xIn
    self.planeY = yIn
    self.planeZ = zIn
    self.height = height
    self.width = width
  }
  
  
  //MARK: NSCoding
  func encode(with aCoder: NSCoder) {
    aCoder.encode(planeX, forKey: PropertyKey.planeX)
    aCoder.encode(planeY, forKey: PropertyKey.planeY)
    aCoder.encode(planeZ, forKey: PropertyKey.planeZ)
    aCoder.encode(height, forKey: PropertyKey.height)
    aCoder.encode(width, forKey: PropertyKey.width)
  }
  
  required convenience init?(coder aDecoder: NSCoder) {
    let planeX = aDecoder.decodeFloat(forKey: PropertyKey.planeX)
    let planeY = aDecoder.decodeFloat(forKey: PropertyKey.planeY)
    let planeZ = aDecoder.decodeFloat(forKey: PropertyKey.planeZ)
    let height = aDecoder.decodeFloat(forKey: PropertyKey.height)
    let width = aDecoder.decodeFloat(forKey: PropertyKey.width)

    // Must call designated initializer.
    self.init(xIn: planeX, yIn: planeY, zIn:planeZ, height: height, width: width)
  }
  
}
