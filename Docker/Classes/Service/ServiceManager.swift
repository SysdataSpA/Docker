//
//  ServiceManager.swift
//  Pods-Docker
//
//  Created by Paolo Ardia on 14/06/18.
//

import UIKit
import Alamofire

class ServiceManager: NSObject {
    static let shared = ServiceManager()
    
    var defaultSessionManager: SessionManager?
    
    override init() {
        self.defaultSessionManager = SessionManager()
        self.defaultSessionManager?.startRequestsImmediately = true
    }
    
    func call(with serviceCall: ServiceCall) {
        guard let sessionManager = serviceCall.service.sessionManager
            else { return }
        guard let baseUrl = serviceCall.service.baseUrl
            else { return }
        let url = baseUrl.appendingPathComponent(serviceCall.service.path)
        var shouldStart = true

        var params: [String:Any]?
        do {
            params = try serviceCall.request.parameters()
        }
        catch {
            self.manageMappingFailure(for: serviceCall, HTTPStatusCode: 0, error: error)
            return
        }
        
        // manca il mapping dei path parameters, trovare alternativa a SOCKit
        
        // gestire le POST in multipart
        
        var dataRequest = sessionManager.request(url,
                                                 method: serviceCall.request.method,
                                                 parameters: params,
                                                 encoding: serviceCall.request.parameterEncoding,
                                                 headers: serviceCall.request.additionalHeaders)
        dataRequest.validate()
        dataRequest.response(responseSerializer: DataRequest.jsonResponseSerializer()) { (<#DataResponse<DataResponseSerializerProtocol.SerializedObject>#>) in
            <#code#>
        }
    }
    
    func manageMappingFailure(for serviceCall:ServiceCall, HTTPStatusCode: Int, error: Error) {
        
    }
}

class ServiceCall : NSObject {
    let service: Service
    let request: ServiceRequest
    
    init(with service: Service, request: ServiceRequest) {
        self.service = service
        self.request = request
        super.init()
    }
}
