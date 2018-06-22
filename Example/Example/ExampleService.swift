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
    var path: String = "/anyway/Sysdata/Paolo"
    var baseUrl: String = "https://www.foaas.com"
    
    var sessionManager: SessionManager {
        return ExampleServiceManager.shared.defaultSessionManager
    }
    
    func responseClass() -> Response.Type {
        return ExampleResponse.self
    }
}

class ExampleServiceRequest: Request {
    var multipartBodyParts: [MultipartBodyPart]?
    
    var service: Service = ExampleService()
    
    var headers: [String : String]? {
        return ["Accept":"application/json"]
    }
}

class ExampleResponse: Response {
    override func decode() -> Decodable? {
        result = Result<Decodable>(value: { () -> Fooas in
            return try JSONDecoder().decode(Fooas.self, from: data)
        })
        return result?.value
    }
}
