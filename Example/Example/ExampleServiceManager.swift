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
    func callService() {
        let service = ExampleService()
        let request = ExampleServiceRequest(with: service)
        let call = ServiceCall(with: service, request: request)
        self.call(with: call)
    }
}
