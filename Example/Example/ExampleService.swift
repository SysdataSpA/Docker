//
//  ExampleService.swift
//  Example
//
//  Created by Paolo Ardia on 18/06/18.
//  Copyright © 2018 Paolo Ardia. All rights reserved.
//

import UIKit
import Docker

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    let documentsDirectory = paths[0]
    return documentsDirectory
}

class ResourcesService: Service {
    required init() {
        super.init()
        self.path = "/resources"
        self.baseUrl = "https://go8pgqn.restletmocks.net"
    }
    
    override var sessionManager: SessionManager {
        return ExampleServiceManager.shared.defaultSessionManager
    }
}

class GetResourcesRequest: Request {
    
    override init() {
        super.init()
        self.service = ResourcesService()
        self.headers = ["Accept":"application/json"]
        self.demoSuccessFileName = "getResources.json"
    }
}

typealias GetResourcesResponse = ResponseJSON<[Resource], ErrorResult>
typealias GetResourcesServiceCall = ServiceCall<[Resource], ErrorResult, GetResourcesResponse>



class PostResourceRequest: Request {

    var resource: Resource
    
    init(resource: Resource) {
        self.resource = resource
        
        super.init()
        self.service = ResourcesService()
        self.headers = ["Content-Type":"application/json", "Accept":"application/json"]
        self.bodyEncoding = .json(JSONEncoder())
        self.method = .post
        self.demoSuccessFileName = "addResource.json"
    }
    
//    override func responseClass() -> Response.Type {
//        return PostResourceResponse.self
//    }
    
    override func bodyParameters() throws -> Encodable? {
        return self.resource
    }
}

class PostResourceResponse: ResponseJSON<Resource, ErrorResult> {

}



class ResourceService: Service {
    required init() {
        super.init()
        self.path = "/resources/:id"
        self.baseUrl = "https://go8pgqn.restletmocks.net"
    }
    
    override var sessionManager: SessionManager {
        return ExampleServiceManager.shared.defaultSessionManager
    }
}


class GetResourceByIdRequest: Request {
    
    var id: Int
    
    init(with id: Int) {
        self.id = id
        super.init()
        self.service = ResourceService()
        self.headers = ["Accept":"application/json"]
        self.demoSuccessFileName = "addResource.json"
    }
    
//    override func responseClass() -> Response.Type {
//        return GetResourceByIdResponse.self
//    }
    
    override func pathParameters() throws -> [String : Any]? {
        return ["id": id]
    }    
}

class GetResourceByIdResponse: ResponseJSON<Resource, ErrorResult> {
}


class UploadService: Service {
    required init() {
        super.init()
        self.path = "/resources/:id/file"
        self.baseUrl = "https://go8pgqn.restletmocks.net"
    }
    
    override var sessionManager: SessionManager {
        return ExampleServiceManager.shared.defaultSessionManager
    }
}

class UploadRequest: Request {
    var id: Int
    
    init(with id: Int) {
        self.id = id
        super.init()
        self.method = .post
        self.service = UploadService()
        self.headers = ["Content-Type":"application/x-www-form-urlencoded"]
        self.multipartBodyParts = try! getParts()
        self.type = .upload(.multipart)
    }
    
//    override func responseClass() -> Response.Type {
//        return UploadResponse.self
//    }
    
    override func pathParameters() throws -> [String : Any]? {
        return ["id": id]
    }
    
    func getParts() throws -> [MultipartBodyPart]? {
        if let url = Bundle.main.url(forResource: "dog", withExtension: "jpg") {
            let data = try Data(contentsOf: url)
            let part = MultipartBodyPart(with: data, name: "image")
            return [part]
        }
        throw URLError(URLError.resourceUnavailable)
    }
}

class UploadResponse: Response<Any, Any> {
}


class DownloadService: Service {
    
    required init() {
        super.init()
        self.path = "/wp-content/uploads/2017/08/cane905-675x905.jpg"
        self.baseUrl = "https://st.ilfattoquotidiano.it/"
    }
    
    override var sessionManager: SessionManager {
        return ExampleServiceManager.shared.defaultSessionManager
    }
}

class DownloadRequest: Request {
    
    override init() {
        super.init()
        self.service = DownloadService()
        self.type = .download({ temporaryURL, response in
            return (getDocumentsDirectory().appendingPathComponent("image.jpg"), [DownloadOptions.removePreviousFile] )
        })
        self.headers = ["Accept":"image/jpeg"]
        self.demoSuccessFileName = "dog.jpg"
    }
    
//    override func responseClass() -> Response.Type {
//        return DownloadResponse.self
//    }
}

class DownloadResponse: Response<Any, Any> {
    override func decode() {
        do {
            let data = try Data(contentsOf: getDocumentsDirectory().appendingPathComponent("image.jpg"))
            guard let value = UIImage(data: data) else {
                setResponseResult(.failure(nil, .generic(nil)))
                return
            }
            setResponseResult(.success(value))
        } catch let err  {
            print(err)
            setResponseResult(.failure(nil, .generic(err)))
        }
    }
}
