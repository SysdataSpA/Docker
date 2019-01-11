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

class GetResourcesRequest: RequestJSON {
    
    override init() {
        super.init()
        self.service = ResourcesService()
        self.demoSuccessFileName = "getResources.json"
    }
}

typealias GetResourcesResponse = ResponseJSON<[Resource], ErrorResult>
typealias GetResourcesServiceCall = ServiceCall<[Resource], ErrorResult, GetResourcesResponse>



class PostResourceRequest: Request {

    init(resource: Resource) {
        super.init()
        self.service = ResourcesService()
        self.headers = ["Content-Type":"application/json", "Accept":"application/json"]
        self.method = .post
        self.demoSuccessFileName = "addResource.json"
        
        self.bodyParameters = resource
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
    
    init(with id: Int) {
        super.init()
        self.service = ResourceService()
        self.headers = ["Accept":"application/json"]
        self.demoSuccessFileName = "addResource.json"
        
        self.pathParameters["id"] = id
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
        
        self.pathParameters["id"] = id
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
                result = .failure(nil, .generic(nil))
                return
            }
            result = .success(value)
        } catch let err  {
            print(err)
            result = .failure(nil, .generic(err))
        }
    }
}
