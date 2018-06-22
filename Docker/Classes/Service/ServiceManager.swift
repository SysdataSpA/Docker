//
//  ServiceManager.swift
//  Pods-Docker
//
//  Created by Paolo Ardia on 14/06/18.
//

import UIKit
import Alamofire

#if BLABBER
import Blabber
#endif

open class ServiceManager: NSObject {
    
    let responseQueue = DispatchQueue(label: "com.sysdata.docker.serializing", qos: .background, attributes: DispatchQueue.Attributes.concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
    var servicesQueue = [ServiceCall]()
    open var defaultSessionManager: SessionManager
    
    
    override public init() {
        self.defaultSessionManager = SessionManager.default
        self.defaultSessionManager.startRequestsImmediately = true
    }
    
    public func call(with serviceCall: ServiceCall) throws {
        servicesQueue.append(serviceCall)
        
        switch serviceCall.request.type {
        case .simple, .bodyData, .jsonEncodableBody, .parameters, .bodyDataAndParameters, .encodedBodyAndParameters:
            try request(serviceCall: serviceCall)
        case .uploadFile(let file):
            try upload(serviceCall: serviceCall, fileURL: file)
        case .uploadMultipart(let multipartBody), .uploadMultipartWithParameters(let multipartBody, _):
            guard !multipartBody.isEmpty && serviceCall.request.method.supportsMultipart else {
                fatalError("\(serviceCall.request.method.rawValue) method does not a multipart upload.")
            }
            try uploadMultipart(serviceCall: serviceCall)
        case .download(let destination), .downloadWithParameters(_, let destination):
            try download(serviceCall: serviceCall, to: destination)
        }
    }
    
    private func request(serviceCall: ServiceCall) throws {
        let urlRequest = try serviceCall.request.asUrlRequest()
        SDLogModuleVerbose(serviceCall.request.description, module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.request(urlRequest as URLRequestConvertible)
        request = request.validate()
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func upload(serviceCall: ServiceCall, fileURL: URL) throws {
        let urlRequest = try serviceCall.request.asUrlRequest()
        SDLogModuleVerbose(serviceCall.request.description, module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.upload(fileURL, with: urlRequest as URLRequestConvertible)
        request = request.validate()
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func uploadMultipart(serviceCall: ServiceCall) throws {
        guard let multipartBodyParts = serviceCall.request.multipartBodyParts else {
            fatalError("Multipart request must contain body parts")
        }
        if multipartBodyParts.count == 0 {
            fatalError("Multipart request must contain body parts")
        }
        
        let multipartFormData: (MultipartFormData) -> Void = { form in
            for bodyPart in multipartBodyParts {
                if let mimeType = bodyPart.mimeType {
                    if let fileName = bodyPart.fileName {
                        form.append(bodyPart.data, withName: bodyPart.name, fileName: fileName, mimeType: mimeType)
                    } else {
                        form.append(bodyPart.data, withName: bodyPart.name, mimeType: mimeType)
                    }
                } else {
                    form.append(bodyPart.data, withName: bodyPart.name)
                }
            }
        }
        
        let urlRequest = try serviceCall.request.asUrlRequest()
        
        serviceCall.service.sessionManager.upload(multipartFormData: multipartFormData, with: urlRequest) { (result) in
            switch result {
            case .success(let request, _, _):
                request.validate()
                self.sendRequest(request: request, serviceCall: serviceCall)
            case .failure(let error):
                let responseClass = serviceCall.service.responseClass()
                let response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: nil)
                let error = DockerError.underlying(error, nil)
                response.error = error
            }
        }
    }
    
    private func download(serviceCall: ServiceCall, to destination: @escaping DownloadRequest.DownloadFileDestination) throws {
        let urlRequest = try serviceCall.request.asUrlRequest()
        SDLogModuleVerbose(serviceCall.request.description, module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.download(urlRequest as URLRequestConvertible, to: destination)
        request = request.validate()
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func sendRequest<T>(request: T, serviceCall: ServiceCall) where T: Requestable, T: Alamofire.Request {
        
        let completionHandler: RequestCompletion = { urlResponse, request, data, error in
            let response: Response
            let responseClass = serviceCall.service.responseClass()
            switch (urlResponse, data, error) {
            case let (.some(urlResponse), data, .none):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
            case let (.some(urlResponse), _, .some(error)):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                let error = DockerError.underlying(error, urlResponse)
                response.error = error
            case let (_, _, .some(error)):
                response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: urlResponse)
                let error = DockerError.underlying(error, nil)
                response.error = error
            default:
                let error = DockerError.underlying(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil), nil)
                response = responseClass.init(statusCode: 0, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                response.error = error
            }
            _ = response.decode()
            SDLogModuleVerbose(response.description, module: DockerServiceLogModuleName)
            serviceCall.completion(response)
        }
        
        let finalRequest = request.response(callbackQueue: nil, completionHandler: completionHandler)
        finalRequest.resume()
    }
}

public typealias ServiceCompletion = (Response) -> Void

public class ServiceCall : NSObject {
    let service: Service
    var request: Request
    var response: Response?
    let completion: ServiceCompletion
    
    public init(with service: Service, request: Request, completion: @escaping ServiceCompletion) {
        self.service = service
        self.request = request
        self.completion = completion
        super.init()
    }
}
