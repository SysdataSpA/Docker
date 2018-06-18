//
//  ServiceManager.swift
//  Pods-Docker
//
//  Created by Paolo Ardia on 14/06/18.
//

import UIKit
import Alamofire

open class ServiceManager: NSObject {
    
    let responseQueue = DispatchQueue(label: "com.sysdata.docker.serializing", qos: .background, attributes: DispatchQueue.Attributes.concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
    var servicesQueue = [ServiceCall]()
    open var defaultSessionManager: SessionManager
    
    
    override public init() {
        self.defaultSessionManager = SessionManager.default
        self.defaultSessionManager.startRequestsImmediately = true
    }
    
    public func call(with serviceCall: ServiceCall) {
        guard let baseUrl = serviceCall.service.baseUrl
            else { return }
        guard let responseSerializer = serviceCall.request.responseSerializer
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
        servicesQueue.append(serviceCall)
        let sessionManager = serviceCall.service.sessionManager
        var dataRequest = sessionManager.request(url,
                                                 method: serviceCall.request.method,
                                                 parameters: params,
                                                 encoding: serviceCall.request.parameterEncoding,
                                                 headers: serviceCall.request.additionalHeaders)
        dataRequest = dataRequest.validate()
        dataRequest.response(queue: nil, responseSerializer: responseSerializer) { (response) in
            print(response)
            let serviceResponse = ServiceResponse(serviceCall.request, response:response)
            guard let resultClass = serviceResponse.resultClass
                else { return }
            
        }
        serviceCall.request.dataRequest = dataRequest
    }
    
    func manageMappingFailure(for serviceCall:ServiceCall, HTTPStatusCode: Int, error: Error) {
        
    }
}

public class ServiceCall : NSObject {
    let service: Service
    let request: ServiceRequest
    
    public init(with service: Service, request: ServiceRequest) {
        self.service = service
        self.request = request
        super.init()
    }
}
