//
//  ExampleService.swift
//  Example
//
//  Created by Paolo Ardia on 18/06/18.
//  Copyright © 2018 Paolo Ardia. All rights reserved.
//

import UIKit
import Docker

class ExampleService: Service {
    override init() {
        super.init()
        self.baseUrl = URL(string: "https://www.foaas.com")
        self.path = "/anyway/Sysdata/Paolo"
        self.sessionManager = ExampleServiceManager.shared.defaultSessionManager
    }
}

class ExampleServiceRequest: ServiceRequest {
    
}
