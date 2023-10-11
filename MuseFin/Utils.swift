//
//  Utils.swift
//  MuseFin
//
//  Created by Brian Huy Vo on 10/11/23.
//

import SwiftUI

extension Dictionary {
   var jsonData: Data? {
      return try? JSONSerialization.data(withJSONObject: self)
   }
       
   func toJSONString() -> String? {
      if let jsonData = jsonData {
         let jsonString = String(data: jsonData, encoding: .utf8)
         return jsonString
      }
      return nil
   }
}
