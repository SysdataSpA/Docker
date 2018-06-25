//
//  ExampleServiceManager.swift
//  Example
//
//  Created by Paolo Ardia on 18/06/18.
//  Copyright © 2018 Paolo Ardia. All rights reserved.
//

import UIKit
import Docker
import Alamofire

struct Resource: Codable {
    let id: String
    let name: String
    let boolean: Bool
    let double: Double
    let nestedObjects: [NestedObject]?
}

struct NestedObject: Codable {
    let id: String
    let name: String
}

class ExampleServiceManager: ServiceManager {
    
    required init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        var httpHeaders = SessionManager.defaultHTTPHeaders
        httpHeaders["Accept"] = "application/json"
        configuration.httpAdditionalHeaders = httpHeaders
        self.defaultSessionManager = SessionManager(configuration: configuration)
    }
    
    func getResources(completion: @escaping (Response) -> Void) {
        let request = GetResourcesRequest()
        let serviceCall = ServiceCall(with: request.service, request: request) { (response) in
            completion(response)
        }
        try! call(with: serviceCall)
    }
    
    func postResource(_ resource:Resource, completion: @escaping (Response) -> Void) {
        let request = PostResourceRequest(resource: resource)
        let serviceCall = ServiceCall(with: request.service, request: request) { (response) in
            completion(response)
        }
        try! call(with: serviceCall)
    }
    
    func downloadImage(completion: @escaping (Response) -> Void) {
        let request = DownloadRequest()
        let serviceCall = ServiceCall(with: request.service, request: request) { (response) in
            completion(response)
        }
        try! call(with: serviceCall)
    }
}
