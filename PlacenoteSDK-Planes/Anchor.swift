//
//  Anchor.swift
//  PlacenoteSDK-Planes
//
//  Created by Prasenjit Mukherjee on 2018-02-02.
//  Copyright © 2018 Vertical AI. All rights reserved.
//

import Foundation
import ModelIO
import SceneKit.ModelIO


extension NSCoder {

  func data<T>(for array: [T]) -> Data {
    return array.withUnsafeBufferPointer { buffer in
      return Data(buffer: buffer)
    }
  }
  
  func array<T>(for data: Data) -> [T] {
    return data.withUnsafeBytes { (bytes: UnsafePointer<T>) -> [T] in
      let buffer = UnsafeBufferPointer(start: bytes, count: data.count / MemoryLayout<T>.stride)
      return Array(buffer)
    }
  }
  
  func encodePOD<T>(_ immutableArray: [T], forKey key: String) {
    encode(data(for: immutableArray), forKey: key)
  }
  
  func decodePOD<T>(forKey key: String) -> [T] {
    return array(for: decodeObject(forKey: key) as? Data ?? Data())
  }
}



class Anchor: NSObject, NSCoding {

  static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
  static let ArchiveURL = DocumentsDirectory.appendingPathComponent("anchors")

  var transform: [matrix_float4x4] = [] //Single transform for one anchor, stored as an array to conform to Sequence type. TODO: Find a way to not have to use an array.
  var planes: [Plane] = []
  
  init(tf: matrix_float4x4) {
    transform.append(tf)
  }
  
  init(tf: matrix_float4x4, planesIn: [Plane]) {
    transform.append(tf)
    planes = planesIn
  }
  
  init(tfs: [matrix_float4x4], planesIn: [Plane]) {
    transform = tfs
    planes = planesIn
  }
  
  func encode(with aCoder: NSCoder) {
    aCoder.encodePOD(transform, forKey: "transformMat")
    aCoder.encode(planes, forKey: "planes")
  }
  
  required convenience init?(coder aDecoder: NSCoder) {
    let tfs : [matrix_float4x4] = aDecoder.decodePOD(forKey: "transformMat")
    let planes: [Plane] = aDecoder.decodeObject(forKey: "planes") as! [Plane]
    self.init(tfs: tfs, planesIn:planes)
  }
}
