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
    
    var servicesQueue = [ServiceCall]()
    open var defaultSessionManager: SessionManager
    
    public static var _shared: Singleton?
    
    open var useDemoMode:Bool = false
    open var timeBeforeRetry: TimeInterval = 3.0
    
    required public init() {
        self.defaultSessionManager = SessionManager.default
        self.defaultSessionManager.startRequestsImmediately = true
    }
    
    public func call(with serviceCall: ServiceCall) throws {
        serviceCall.isProcessing = true
        servicesQueue.append(serviceCall)
        
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
    
    private func request(serviceCall: ServiceCall) throws {
        let urlRequest = try serviceCall.request.asUrlRequest()
        serviceCall.request.urlRequest = urlRequest
        SDLogModuleInfo("Service Manager: start \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.request(urlRequest as URLRequestConvertible)
        request = request.validate()
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func upload(serviceCall: ServiceCall, fileURL: URL) throws {
        let urlRequest = try serviceCall.request.asUrlRequest()
        serviceCall.request.urlRequest = urlRequest
        SDLogModuleInfo("Service Manager: start upload \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.upload(fileURL, with: urlRequest as URLRequestConvertible)
        request = request.validate()
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func uploadMultipart(serviceCall: ServiceCall) throws {
        if !serviceCall.request.method.supportsMultipart {
            throw DockerError.multipartNotSupported(serviceCall.request.method)
        }
        guard let multipartBodyParts = serviceCall.request.multipartBodyParts else {
            throw DockerError.emptyMultipartBody(serviceCall)
        }
        if multipartBodyParts.count == 0 {
            throw DockerError.emptyMultipartBody(serviceCall)
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
        serviceCall.request.urlRequest = urlRequest
        SDLogModuleInfo("Service Manager: start upload multipart \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        
        serviceCall.service.sessionManager.upload(multipartFormData: multipartFormData, with: urlRequest) { [weak self] (result) in
            switch result {
            case .success(let request, _, _):
                request.validate()
                self?.sendRequest(request: request, serviceCall: serviceCall)
            case .failure(let error):
                let responseClass = serviceCall.request.responseClass()
                let response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: nil)
                response.error = DockerError.underlying(error, nil, response.httpStatusCode)
            }
        }
    }
    
    private func download(serviceCall: ServiceCall, to destination: @escaping DownloadRequest.DownloadFileDestination) throws {
        let urlRequest = try serviceCall.request.asUrlRequest()
        serviceCall.request.urlRequest = urlRequest
        SDLogModuleInfo("Service Manager: start download \(serviceCall.request.shortDescription)", module: DockerServiceLogModuleName)
        var request = serviceCall.service.sessionManager.download(urlRequest as URLRequestConvertible, to: destination)
        request = request.validate()
        sendRequest(request: request, serviceCall: serviceCall)
    }
    
    private func sendRequest<T>(request: T, serviceCall: ServiceCall) where T: Requestable, T: Alamofire.Request {
        
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
            let response: Response
            let responseClass = serviceCall.request.responseClass()
            switch (urlResponse, data, error) {
            case let (.some(urlResponse), data, .none):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
            case let (.some(urlResponse), _, .some(error)):
                response = responseClass.init(statusCode: urlResponse.statusCode, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                response.error = DockerError.underlying(error, urlResponse, response.httpStatusCode)
            case let (_, _, .some(error)):
                response = responseClass.init(statusCode: 0, data: Data(), request: serviceCall.request, response: urlResponse)
                response.error = DockerError.underlying(error, nil, response.httpStatusCode)
            default:
                response = responseClass.init(statusCode: 0, data: data ?? Data(), request: serviceCall.request, response: urlResponse)
                let error = DockerError.underlying(NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil), nil, response.httpStatusCode)
                response.error = error
            }
            self?.completeServiceCall(serviceCall, with: response)
        }
        
        // call the request
        let finalRequest = request.response(callbackQueue: nil, completionHandler: completionHandler)
        finalRequest.resume()
    }
    
    
    fileprivate func completeServiceCall(_ serviceCall:ServiceCall, with response:Response) {
        response.decode()
        SDLogModuleInfo("\nService Manager: complete service with \(response.shortDescription)", module: DockerServiceLogModuleName)
        SDLogModuleVerbose("--------------------------------\n\(serviceCall.request.description)", module: DockerServiceLogModuleName)
        SDLogModuleVerbose("--------------------------------\n\(response.description)", module: DockerServiceLogModuleName)
        serviceCall.completion(response)
        remove(serviceCall)
    }
    
    private func remove(_ serviceCall: ServiceCall) {
        if let index = self.servicesQueue.index(of: serviceCall) {
            serviceCall.isProcessing = false
            self.servicesQueue.remove(at: index)
        }
    }
}

//MARK: Demo mode
extension ServiceManager {
    public func callServiceInDemoMode(with serviceCall:ServiceCall) throws {
        serviceCall.request.sentInDemoMode = true
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
            if !success {
                response.error = DockerError.underlying(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: statusCode)), nil, statusCode)
            }
            DispatchQueue.main.async { [weak self] in
                self?.completeServiceCall(serviceCall, with: response)
            }
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
        let waitingTime: Double.random(in: serviceCall.request.demoWaitingTimeRange)
        #else
        let waitingDifference = serviceCall.request.demoWaitingTimeRange.upperBound - serviceCall.request.demoWaitingTimeRange.lowerBound
        let waitingTime: Double = Double(arc4random_uniform(UInt32(waitingDifference*100.0)))/100.0 + serviceCall.request.demoWaitingTimeRange.lowerBound
        #endif
        return waitingTime
    }
}

//MARK: Automatic Retry
extension ServiceManager {
    private func shouldCatchFailureForMissingResponse(in serviceCall: ServiceCall) -> Bool {
        if serviceCall.numOfAutomaticRetry > 0 {
            
            return true
        }
        return false
    }
    
    public func performAutomaticRetry(of serviceCall:ServiceCall) {
        if !serviceCall.isProcessing {
            SDLogModuleInfo("Repeat service \(serviceCall)", module: kServiceManagerLogModuleName)
            remove(serviceCall)
            serviceCall.numOfAutomaticRetry -= 1
            try? call(with: serviceCall)
        }
    }
}

public typealias ServiceCompletion = (Response) -> Void

public class ServiceCall : NSObject {
    let service: Service
    var request: Request
    var response: Response?
    let completion: ServiceCompletion
    let progressBlock: ProgressHandler?
    var numOfAutomaticRetry: UInt = 0
    var isProcessing: Bool = false
    
    public init(with request: Request, service: Service? = nil, progressBlock: ProgressHandler? = nil, completion: @escaping ServiceCompletion) {
        if let service = service {
            self.service = service
        } else {
            self.service = request.service
        }
        
        self.request = request
        self.completion = completion
        self.progressBlock = progressBlock
        super.init()
    }
}
