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

struct ErrorResult: Decodable {
    
}

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
    
    public static var shared = ServiceManager()
    
    required init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        var httpHeaders = SessionManager.defaultHTTPHeaders
        httpHeaders["Accept"] = "application/json"
        configuration.httpAdditionalHeaders = httpHeaders
        self.defaultSessionManager = SessionManager(configuration: configuration)
    }
    
    func getResources(completion: @escaping ([Resource]) -> Void) {
        let request = GetResourcesRequest()
        let serviceCall: GetResourcesServiceCall = ServiceCall(with: request) { (response) in
            guard let result = response.result, case let ResponseResult.success(resources) = result  else {
                completion([])
                return
            }
            completion(resources)
        }
        call(with: serviceCall)
    }
    
    func postResource(_ resource:Resource, completion: @escaping (PostResourceResponse) -> Void) {
        let request = PostResourceRequest(resource: resource)
        let serviceCall: PostResourceServiceCall = ServiceCall(with: request) { (response) in
            completion(response)
        }
        call(with: serviceCall)
    }

    func getResource(with id: Int, completion: @escaping (GetResourceByIdResponse) -> Void) {
        let request = GetResourceByIdRequest(with: id)
        let serviceCall = GetResourceByIdServiceCall(with: request) { (response) in
            completion(response)
        }
        call(with: serviceCall)
    }
    
    func uploadImage(completion: @escaping (UploadResponse) -> Void) {
        let request = UploadRequest(with: 1)
        let serviceCall = UploadServiceCall(with: request, progressBlock: { (progress) in
            print("Progress: \(progress)")
        }) { (response) in
            completion(response)
        }
        call(with: serviceCall)
    }
    
    func downloadImage(completion: @escaping (DownloadResponse) -> Void) {
        let request = DownloadRequest()
        let serviceCall = DownloadServiceCall(with: request, progressBlock: { (progress) in
            print("Progress: \(progress)")
        }) { (response) in
            completion(response)
        }
        call(with: serviceCall)
    }
}
