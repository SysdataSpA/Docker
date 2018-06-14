//
//  ServiceGeneric.swift
//  Pods-Docker
//
//  Created by Paolo Ardia on 14/06/18.
//

import UIKit

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case head = "HEAD"
    case patch = "PATCH"
}

struct MultipartBodyInfo {
    var data: Data?
    var name: String?
    var filename: String?
    var mimeType: String?
}

class ServiceGeneric: NSObject {

}
