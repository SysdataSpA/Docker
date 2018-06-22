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

struct Fooas: Codable {
    let message: String
    let subtitle: String
}

class ExampleServiceManager: ServiceManager {
    public static let shared = ExampleServiceManager()
    
    override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        var httpHeaders = SessionManager.defaultHTTPHeaders
        httpHeaders["Accept"] = "application/json"
        configuration.httpAdditionalHeaders = httpHeaders
        self.defaultSessionManager = SessionManager(configuration: configuration)
    }
    
    func callExampleService(completion: (ExampleResponse) -> Void) {
        let request = ExampleServiceRequest()
        let serviceCall = ServiceCall(with: request.service, request: request) { (response) in
            print(response.result as Any)
        }
        try? call(with: serviceCall)
    }
}
