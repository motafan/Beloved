//
//  Client+JSON.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation
import Combine

public struct JsonResponse<T>: Codable, Sendable where T: Codable, T: Sendable {
    public let code: Int
    public let msg: String
    public let data: T?
}

@dynamicMemberLookup
public struct JSONBody: @unchecked Sendable {
    
    private let propertyQueue = DispatchQueue(label: "org.tikfoi.Beloved.JSONBodyQueue")
    
    private(set) var dictionary: Dictionary<String, Any> = [:]
    
    var data: Data? {
        propertyQueue.sync {
            if dictionary.isEmpty {
                return nil
            }
            
            return try? JSONSerialization.data(withJSONObject: dictionary)
        }
    }
    
    subscript(dynamicMember member: String) -> Any {
        get { propertyQueue.sync { dictionary[member] as Any } }
        set { propertyQueue.sync { dictionary[member] = newValue } }
    }
    
    subscript<T>(dynamicMember member: String) -> T {
        get {
            propertyQueue.sync {
                guard let value = dictionary[member] as? T else {
                    fatalError("Cast type error: '\(member)' could not cast value of type '\(String(reflecting: T.self))'")
                }
                return value
            }
        }
        set { propertyQueue.sync { dictionary[member] = newValue } }
    }
}



public extension HttpClient {
    
    typealias BobyBuilder = @Sendable (inout JSONBody) -> Void
    
    typealias ParametersBuilder = (inout Parameters) -> Void
    
    func send<T>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: BobyBuilder? = nil) async throws -> JsonResponse<T> where T: Swift.Codable, T: Swift.Sendable {
        
        let baseString = ""
        let baseURL = URL(string: baseString)!
        fatalError()
        var body = JSONBody()
        build?(&body)
        
        let r = JSONCodableRequest<JsonResponse<T>>(method: method, baseURL: baseURL, path: path, parameters: body.dictionary)
        
        let response = try await send(r)
        
        guard response.code == 0 else {
            throw BelovedError.responseFailed(code: response.code, message: response.msg)
        }
        
        return response
        
    }
    
    func unsafeSend<T>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: BobyBuilder? = nil) async throws -> T where T: Swift.Codable, T: Swift.Sendable {
        let response = try await send(method: method, path: path, data: data, build)
        guard let data =  response.data else {
            throw BelovedError.invalidData
        }
        return data
    }
    
    @Sendable func send<T>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: BobyBuilder? = nil) -> AnyPublisher<JsonResponse<T>, Error> where T: Swift.Codable, T: Swift.Sendable {
        Future { promise in
            nonisolated(unsafe) let promise = promise
            Task {
                let baseString = ""
                fatalError()
                let baseURL = URL(string: baseString)!
                var body = JSONBody()
                build?(&body)
                let r = JSONCodableRequest<JsonResponse<T>>(method: method, baseURL: baseURL, path: path, parameters: body.dictionary)
                
                do {
                    let response = try await  self.send(r)
                    promise(.success(response))
                } catch  {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    
    func unsafeSend<T: Sendable>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: BobyBuilder? = nil) -> AnyPublisher<T, Error> where T: Swift.Codable {
        send(method: method, path: path, data: data, build)
            .tryMap { response in
                guard let data = response.data else {
                    throw BelovedError.invalidData
                }
                return data
            }
            .eraseToAnyPublisher()
    }
    
    
    
    //    func send<T>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: ParametersBuilder? = nil) async throws -> JsonResponse<T> where T: Swift.Codable {
    //
    //        let baseString =  await Store.mainStore.config.paymentHost
    //        let baseURL = URL(string: baseString)!
    //
    //        var parameters = Parameters()
    //        build?(&parameters)
    //        let r = JsonCodableRequest<JsonResponse<T>>(method: method, baseURL: baseURL, path: path, parameters: parameters)
    //
    //        let response = try await send(r)
    //
    //        guard response.code == 0 else {
    //            throw FetchError.responseFailed(code: response.code, message: response.msg)
    //        }
    //
    //        return response
    //    }
    //
    //
    //    func unsafeSend<T>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: ParametersBuilder? = nil) async throws -> T where T: Swift.Codable {
    //
    //        let response = try await send(method: method, path: path, data: data, build)
    //        guard let data =  response.data else {
    //            throw FetchError.invalidData
    //        }
    //        return data
    //    }
    
    
    //    func send<T>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: ParametersBuilder? = nil) -> AnyPublisher<JsonResponse<T>, Error> where T: Swift.Codable {
    //        Future { promise in
    //            Task {
    //                let baseString = await Store.mainStore.config.paymentHost
    //                let baseURL = URL(string: baseString)!
    //                var parameters = Parameters()
    //                build?(&parameters)
    //                let r = JsonCodableRequest<JsonResponse<T>>(method: method, baseURL: baseURL, path: path, parameters: parameters)
    //
    //                do {
    //                    let response = try await  self.send(r)
    //                    promise(.success(response))
    //                } catch  {
    //                    promise(.failure(error))
    //                }
    //            }
    //        }
    //        .eraseToAnyPublisher()
    //    }
    //
    //
    //    func unsafeSend<T>(method: HTTPMethod = .post, path: String, data: T.Type, _ build: ParametersBuilder? = nil) -> AnyPublisher<T, Error> where T: Swift.Codable {
    //        send(method: method, path: path, data: data, build)
    //            .tryMap { response in
    //                guard let data = response.data else {
    //                    throw FetchError.invalidData
    //                }
    //                return data
    //            }
    //            .eraseToAnyPublisher()
    //    }
    
}
