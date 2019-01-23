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

open class ServiceManager { // : Singleton, Initializable
    
    public var defaultSessionManager: SessionManager
    
    public var useDemoMode:Bool = false
    public var timeBeforeRetry: TimeInterval = 3.0
    
    required public init() {
        defaultSessionManager = SessionManager.default
        defaultSessionManager.startRequestsImmediately = true
    }
    
    public func call<Resp: Responsable>(with serviceCall: ServiceCall<Resp>) {
        serviceCall.isProcessing = true
        
        do {
            if useDemoMode || serviceCall.request.useDemoMode {
                try callServiceInDemoMode(with: serviceCall)
                return
            }
            
            switch serviceCall.request.type {
            case .data:
                try request(serviceCall: serviceCall)
            case .upload(let uploadType):
                switch uploadType {
                case .file(let fileUrl):
                    try upload(serviceCall: serviceCall, fileURL: fileUrl)
                case .multipart:
                    try uploadMultipart(serviceCall: serviceCall)
                }
            case .download(let destination):
                try download(serviceCall: serviceCall, to: destination)
            }
        } catch {
            let responseClass = Resp.self
            let response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: nil)
            completeServiceCall(serviceCall, with: response, error: error as? DockerError ?? .generic(error))
        }
    }
    
    private func request<Resp: Responsable>(serviceCall: ServiceCall<Resp>) throws {
        let urlRequest = try serviceCall.request.buildUrlRequest()
        SDLogModuleInfo("🌍▶️ Service Manager: start \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        let request = serviceCall.service.sessionManager.request(urlRequest as URLRequestConvertible).validate()
        serviceCall.request.internalRequest = request
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func upload<Resp: Responsable>(serviceCall: ServiceCall<Resp>, fileURL: URL) throws {
        let urlRequest = try serviceCall.request.buildUrlRequest()
        SDLogModuleInfo("🌍▶️ Service Manager: start upload \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.upload(fileURL, with: urlRequest as URLRequestConvertible).validate()
        serviceCall.request.internalRequest = request
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func uploadMultipart<Resp: Responsable>(serviceCall: ServiceCall<Resp>) throws {
        if !serviceCall.request.method.supportsMultipart {
            throw DockerError.multipartNotSupported(serviceCall.request.method)
        }
        guard let multipartBodyParts = serviceCall.request.multipartBodyParts else {
            throw DockerError.emptyMultipartBody()
        }
        if multipartBodyParts.count == 0 {
            throw DockerError.emptyMultipartBody()
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
        
        let urlRequest = try serviceCall.request.buildUrlRequest()
        SDLogModuleInfo("🌍▶️ Service Manager: start upload multipart \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        
        serviceCall.service.sessionManager.upload(multipartFormData: multipartFormData, with: urlRequest) { [weak self] (result) in
            switch result {
            case .success(let request, _, _):
                request.validate()
                serviceCall.request.internalRequest = request
                self?.sendRequest(request: request, serviceCall: serviceCall)
            case .failure(let error):
                let responseClass = Resp.self
                var response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: nil)
                response.result = .failure(nil, DockerError.underlying(error, nil, response.httpStatusCode))
            }
        }
    }
    
    private func download<Resp: Responsable>(serviceCall: ServiceCall<Resp>, to destination: @escaping DownloadRequest.DownloadFileDestination) throws {
        let urlRequest = try serviceCall.request.buildUrlRequest()
        SDLogModuleInfo("🌍▶️ Service Manager: start download \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.download(urlRequest as URLRequestConvertible, to: destination).validate()
        serviceCall.request.internalRequest = request
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func sendRequest<T, Resp: Responsable>(request: T, serviceCall: ServiceCall<Resp>) where T: Requestable, T: Alamofire.Request {
        
        // Progress callback management
        var progressRequest = request
        
        if let progressBlock = serviceCall.progressBlock {
            switch progressRequest {
            case let downloadRequest as DownloadRequest:
                if let downloadRequest = downloadRequest.downloadProgress(closure: progressBlock) as? T {
                    progressRequest = downloadRequest
                }
            case let uploadRequest as UploadRequest:
                if let uploadRequest = uploadRequest.uploadProgress(closure: progressBlock) as? T {
                    progressRequest = uploadRequest
                }
            case let dataRequest as DataRequest:
                if let dataRequest = dataRequest.downloadProgress(closure: progressBlock) as? T {
                    progressRequest = dataRequest
                }
            default: break
            }
        }
        
        // completion block management
        let completionHandler: RequestCompletion = { [weak self] urlResponse, request, data, error in
            let response: Resp
            let retrievedData = !(data?.isEmpty ?? true) ? data : nil
            let responseClass = Resp.self
            var responseError: DockerError?
            switch (urlResponse, retrievedData, error) {
            case let (.some(urlResponse), .some(retrievedData), .none):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: retrievedData, request: serviceCall.request, response: urlResponse)
                break
            case let (.some(urlResponse), .some(retrievedData), .some(error)):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: retrievedData, request: serviceCall.request, response: urlResponse)
                responseError = DockerError.underlying(error, urlResponse, response.httpStatusCode)
                break
            default:
                response = responseClass.init(statusCode: 0, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                var httpErrorCode = NSURLErrorUnknown
                if let err = error as? NSError {
                    httpErrorCode = err.code
                }
                responseError = DockerError.missingResponse(error ?? NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil), httpErrorCode)
            }
            self?.completeServiceCall(serviceCall, with: response, error: responseError)
        }
        
        // call the request
        let finalRequest = request.response(callbackQueue: nil, completionHandler: completionHandler)
        finalRequest.resume()
    }
    
    open func completeServiceCall<Resp: Responsable>(_ serviceCall: ServiceCall<Resp>, with response: Resp, error: DockerError?) {
        if error != nil || (serviceCall.request.useDifferentResponseForErrors && serviceCall.request.httpErrorStatusCodeRange.contains(response.httpStatusCode)) {
            SDLogModuleError("🌍‼️ Service completed service with error \(error)", module: DockerServiceLogModuleName)
            
            // errori da mappare eventualmente
            SDLogModuleVerbose("🌍‼️ Trying to map error response", module: DockerServiceLogModuleName)
            response.decodeError(with: error ?? .generic(nil))
        } else {
            response.decode()
        }
        SDLogModuleInfo("🌍 Service completed with response \(response.shortDescription)", module: DockerServiceLogModuleName)
        SDLogModuleVerbose("🌍🌍🌍🌍🌍\n\(serviceCall.request.description)\n\(response.description)\n🌍🌍🌍🌍🌍", module: DockerServiceLogModuleName)
        serviceCall.completion(response)
    }
}

//MARK: Demo mode
extension ServiceManager {
    public func callServiceInDemoMode<Resp: Responsable>(with serviceCall:ServiceCall<Resp>) throws {
        serviceCall.request.sentInDemoMode = true
        #if swift(>=4.2)
        let failureValue = Double.random(in: 0.0...1.0)
        #else
        let failureValue: Double = Double(arc4random_uniform(1000))/1000.0
        #endif
        let success: Bool = failureValue > serviceCall.request.demoFailureChance
        let path = try findDemoFilePath(with: serviceCall, forSuccess: success)
        let data = try loadDemoFile(with: serviceCall, at: path)
        let statusCode: Int = success ? serviceCall.request.demoSuccessStatusCode : serviceCall.request.demoFailureStatusCode
        let waitingTime = self.waitingTime(for: serviceCall)
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + waitingTime) { [weak self] in
            let responseClass = Resp.self
            let response = responseClass.init(statusCode: statusCode, data: data, request: serviceCall.request)
            var error: DockerError?
            if !success {
                error = DockerError.underlying(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode)), nil, statusCode)
            }
            DispatchQueue.main.async { [weak self] in
                self?.completeServiceCall(serviceCall, with: response, error: error)
            }
        }
    }
    
    private func findDemoFilePath<Resp: Responsable>(with serviceCall:ServiceCall<Resp>, forSuccess success:Bool) throws -> String {
        let filename: String
        if success {
            guard let file = serviceCall.request.demoSuccessFileName else {
                throw DockerError.nilSuccessDemoFile()
            }
            filename = file
        } else {
            guard let file = serviceCall.request.demoFailureFileName else {
               throw DockerError.nilFailureDemoFile()
            }
            filename = file
        }
        
        guard let path = serviceCall.request.demoFilesBundle.path(forResource: filename, ofType: nil) else {
            throw DockerError.demoFileNotFound(filename)
        }
        
        return path
    }
    
    private func loadDemoFile<Resp: Responsable>(with serviceCall:ServiceCall<Resp>, at path:String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }
    
    private func waitingTime<Resp: Responsable>(for serviceCall:ServiceCall<Resp>) -> TimeInterval {
        #if swift(>=4.2)
        let waitingTime = Double.random(in: serviceCall.request.demoWaitingTimeRange)
        #else
        let waitingDifference = serviceCall.request.demoWaitingTimeRange.upperBound - serviceCall.request.demoWaitingTimeRange.lowerBound
        let waitingTime: Double = Double(arc4random_uniform(UInt32(waitingDifference*100.0)))/100.0 + serviceCall.request.demoWaitingTimeRange.lowerBound
        #endif
        return waitingTime
    }
}

// MARK: Service Call
public typealias ServiceCompletion<Resp: Responsable> = (Resp) -> Void

public protocol ServiceCallable {
    associatedtype Resp: Responsable
    
    var service: Service { get }
    var request: Request { get }
    
    var completion: ServiceCompletion<Resp> { get }
    var progressBlock: ProgressHandler? { get }
    
    weak var delegate: ServiceManager? { get }
    
    var isProcessing: Bool { get }
    
    func cancel()
    func call()
}

open class ServiceCall<Resp: Responsable>: ServiceCallable {
    
    open var service: Service
    open var request: Request
    
    open var completion: ServiceCompletion<Resp>
    open var progressBlock: ProgressHandler?
    
    open weak var delegate: ServiceManager?
    
    public var isProcessing: Bool = false
    
    public init(with request: Request, service: Service? = nil, delegate: ServiceManager? = nil, progressBlock: ProgressHandler? = nil, completion: @escaping ServiceCompletion<Resp>) {
        if let service = service {
            self.service = service
        } else {
            self.service = request.service
        }
        
        self.request = request
        self.delegate = delegate
        self.completion = completion
        self.progressBlock = progressBlock
    }
    
    public func cancel() {
        request.cancel()
    }
    
    public func call() {
        delegate?.call(with: self)
    }
}
