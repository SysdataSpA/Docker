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
    
    public func call<Val, ErrVal, Resp: Response<Val, ErrVal>>(with serviceCall: ServiceCall<Val, ErrVal, Resp>) throws {
        serviceCall.isProcessing = true
        
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
    }
    
    private func request<Val, ErrVal, Resp: Response<Val, ErrVal>>(serviceCall: ServiceCall<Val, ErrVal, Resp>) throws {
        let urlRequest = try serviceCall.request.buildUrlRequest()
        SDLogModuleInfo("🌍▶️ Service Manager: start \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        let request = serviceCall.service.sessionManager.request(urlRequest as URLRequestConvertible).validate()
        serviceCall.request.internalRequest = request
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func upload<Val, ErrVal, Resp: Response<Val, ErrVal>>(serviceCall: ServiceCall<Val, ErrVal, Resp>, fileURL: URL) throws {
        let urlRequest = try serviceCall.request.buildUrlRequest()
        SDLogModuleInfo("🌍▶️ Service Manager: start upload \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.upload(fileURL, with: urlRequest as URLRequestConvertible).validate()
        serviceCall.request.internalRequest = request
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func uploadMultipart<Val, ErrVal, Resp: Response<Val, ErrVal>>(serviceCall: ServiceCall<Val, ErrVal, Resp>) throws {
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
                let responseClass = serviceCall.responseType
                let response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: nil)
                response.result = .failure(nil, DockerError.underlying(error, nil, response.httpStatusCode))
            }
        }
    }
    
    private func download<Val, ErrVal, Resp: Response<Val, ErrVal>>(serviceCall: ServiceCall<Val, ErrVal, Resp>, to destination: @escaping DownloadRequest.DownloadFileDestination) throws {
        let urlRequest = try serviceCall.request.buildUrlRequest()
        SDLogModuleInfo("🌍▶️ Service Manager: start download \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.download(urlRequest as URLRequestConvertible, to: destination).validate()
        serviceCall.request.internalRequest = request
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func sendRequest<T, Val, ErrVal, Resp: Response<Val, ErrVal>>(request: T, serviceCall: ServiceCall<Val, ErrVal, Resp>) where T: Requestable, T: Alamofire.Request {
        
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
            let response: Response<Val, ErrVal>
            let responseClass = serviceCall.responseType
            var responseError: DockerError?
            switch (urlResponse, data, error) {
            case let (.some(urlResponse), data, .none):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                break
            case let (.some(urlResponse), _, .some(error)):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                responseError = DockerError.underlying(error, urlResponse, response.httpStatusCode)
                break
            case let (_, _, .some(error)):
                response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: urlResponse)
                responseError = DockerError.underlying(error, nil, response.httpStatusCode)
                break
            default:
                response = responseClass.init(statusCode: 0, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                let error = DockerError.underlying(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil), nil, response.httpStatusCode)
                responseError = error
            }
            self?.completeServiceCall(serviceCall, with: response, error: responseError)
        }
        
        // call the request
        let finalRequest = request.response(callbackQueue: nil, completionHandler: completionHandler)
        finalRequest.resume()
    }
    
    
    open func completeServiceCall<Val, ErrVal, Resp>(_ serviceCall: ServiceCall<Val, ErrVal, Resp>, with response: Response<Val, ErrVal>, error: DockerError?) {
        if error != nil || (serviceCall.request.useDifferentResponseForErrors && serviceCall.request.httpErrorStatusCodeRange.contains(response.httpStatusCode)) {
            SDLogModuleInfo("🌍‼️ Service completed service with error \(error)", module: DockerServiceLogModuleName)
            // errori da mappare eventualmente
            SDLogModuleInfo("🌍‼️ Trying to map error response", module: DockerServiceLogModuleName)
            response.decodeError(with: error)
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
    public func callServiceInDemoMode<Val, ErrVal, Resp: Response<Val, ErrVal>>(with serviceCall:ServiceCall<Val, ErrVal, Resp>) throws {
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
            let responseClass = serviceCall.responseType
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
    
    private func findDemoFilePath<Val, ErrVal, Resp: Response<Val, ErrVal>>(with serviceCall:ServiceCall<Val, ErrVal, Resp>, forSuccess success:Bool) throws -> String {
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
    
    private func loadDemoFile<Val, ErrVal, Resp: Response<Val, ErrVal>>(with serviceCall:ServiceCall<Val, ErrVal, Resp>, at path:String) throws -> Data {
        let url = URL(fileURLWithPath: path)
        return try Data(contentsOf: url)
    }
    
    private func waitingTime<Val, ErrVal, Resp: Response<Val, ErrVal>>(for serviceCall:ServiceCall<Val, ErrVal, Resp>) -> TimeInterval {
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

public typealias ServiceCompletion<Val, ErrVal> = (Response<Val, ErrVal>) -> Void

public class ServiceCall<Val, ErrVal, Resp: Response<Val, ErrVal>> {
    
    public let service: Service
    public var request: Request
    public var response: Resp?
    
    let completion: ServiceCompletion<Val, ErrVal>
    let progressBlock: ProgressHandler?
    public var isProcessing: Bool = false
    internal var responseType = Resp.self
    
    public init(with request: Request, service: Service? = nil, progressBlock: ProgressHandler? = nil, completion: @escaping ServiceCompletion<Val, ErrVal>) {
        if let service = service {
            self.service = service
        } else {
            self.service = request.service
        }
        
        self.request = request
        self.completion = completion
        self.progressBlock = progressBlock
    }
}
