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

open class ServiceManager: Singleton, Initializable {

    let responseQueue = DispatchQueue(label: "com.sysdata.docker.serializing", qos: .background, attributes: DispatchQueue.Attributes.concurrent, autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit, target: nil)
    var servicesQueue = [ServiceCall]()
    open var defaultSessionManager: SessionManager
    
    public static var _shared: Singleton?
    
    open var useDemoMode:Bool = false
    
    
    required public init() {
        self.defaultSessionManager = SessionManager.default
        self.defaultSessionManager.startRequestsImmediately = true
    }
    
    public func call(with serviceCall: ServiceCall) throws {
        servicesQueue.append(serviceCall)
        
        if useDemoMode || serviceCall.request.useDemoMode {
            try callServiceInDemoMode(with: serviceCall)
            return
        }
        
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
        
        serviceCall.service.sessionManager.upload(multipartFormData: multipartFormData, with: urlRequest) { [weak self] (result) in
            switch result {
            case .success(let request, _, _):
                request.validate()
                self?.sendRequest(request: request, serviceCall: serviceCall)
            case .failure(let error):
                let responseClass = serviceCall.request.responseClass()
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
        
        let completionHandler: RequestCompletion = { [weak self] urlResponse, request, data, error in
            let response: Response
            let responseClass = serviceCall.request.responseClass()
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
            self?.completeServiceCall(serviceCall, with: response)
        }
        
        let finalRequest = request.response(callbackQueue: nil, completionHandler: completionHandler)
        finalRequest.resume()
    }
    
    fileprivate func completeServiceCall(_ serviceCall:ServiceCall, with response:Response) {
        _ = response.decode()
        SDLogModuleVerbose(response.description, module: DockerServiceLogModuleName)
        serviceCall.completion(response)
        if let index = self.servicesQueue.index(of: serviceCall) {
            self.servicesQueue.remove(at: index)
        }
    }
}

//MARK: Demo mode
extension ServiceManager {
    fileprivate func callServiceInDemoMode(with serviceCall:ServiceCall) throws {
        #if swift(>=4.2)
        let failureValue: Double.random(in: 0.0...1.0)
        #else
        let failureValue: Double = Double(arc4random_uniform(1000))/1000.0
        #endif
        let success: Bool = failureValue > serviceCall.request.demoFailureChance
        let path = try findDemoFilePath(with: serviceCall, forSuccess: success)
        let data = try loadDemoFile(with: serviceCall, at: path)
        let statusCode: Int = success ? serviceCall.request.demoSuccessStatusCode : serviceCall.request.demoFailureStatusCode
        let waitingTime = self.waitingTime(for: serviceCall)
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + waitingTime) { [weak self] in
            let responseClass = serviceCall.request.responseClass()
            let response = responseClass.init(statusCode: statusCode, data: data, request: serviceCall.request)
            self?.completeServiceCall(serviceCall, with: response)
        }
    }
    
    private func findDemoFilePath(with serviceCall:ServiceCall, forSuccess success:Bool) throws -> String {
        let filename: String
        if success {
            if let file = serviceCall.request.demoSuccessFileName {
                filename = file
            } else {
                throw DockerError.nilSuccessDemoFile(serviceCall)
            }
        } else {
            if let file = serviceCall.request.demoFailureFileName {
                filename = file
            } else {
                throw DockerError.nilFailureDemoFile(serviceCall)
            }
        }
        
        guard let path = serviceCall.request.demoFilesBundle.path(forResource: filename, ofType: nil) else {
            throw DockerError.demoFileNotFound(serviceCall, filename)
        }
        
        return path
    }
    
    private func loadDemoFile(with serviceCall:ServiceCall, at path:String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }
    
    private func waitingTime(for serviceCall:ServiceCall) -> TimeInterval {
        #if swift(>=4.2)
        let waitingTime: Double.random(in: serviceCall.request)
        #else
        let waitingDifference = serviceCall.request.demoWaitingTimeRange.upperBound - serviceCall.request.demoWaitingTimeRange.lowerBound
        let waitingTime: Double = Double(arc4random_uniform(UInt32(waitingDifference*100.0)))/100.0 + serviceCall.request.demoWaitingTimeRange.lowerBound
        #endif
        return waitingTime
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
