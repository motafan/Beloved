//
//  HttpClient.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation
import Combine


final public class HttpClient: Sendable {
    
    public static let shared = HttpClient()
    
    private let urlSession = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: .current)
       
    public func send<R>(_ request: R) async throws -> R.Response where R: Request {
        let urlRequest = makeURLRequest(for: request)
        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let r = response as? HTTPURLResponse, r.statusCode == 200 else {
            if let httResponse = response as? HTTPURLResponse {
                throw BelovedError.responseFailed(code: httResponse.statusCode, message: HTTPURLResponse.localizedString(forStatusCode: httResponse.statusCode))
            }
            throw BelovedError.badResponse
        }
       
        let entity = try request.dataParser.parse(request: request, data: data)
        return entity
    }

    
    public func send<R>(_ request: R) -> AnyPublisher<R.Response, Error> where R: Request {
        let urlRequest = makeURLRequest(for: request)
        return urlSession.dataTaskPublisher(for: urlRequest)
            .tryMap { (data: Data, response: URLResponse) in
                try request.dataParser.parse(request: request, data: data)
            }
            .eraseToAnyPublisher()
    }
    
    /// 获取元数据
    func fetchMetadata(forFileAtURL url: URL) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: url)
        // 使用 HEAD 方法获取文件元数据
        request.httpMethod = "HEAD"
        let result = try await urlSession.data(for: request)
        return (result.0, result.1 as! HTTPURLResponse)
    }
    
}


extension HttpClient {
    
    fileprivate func makeURLRequest(for request: some Request) -> URLRequest {
        var urlComponents = URLComponents(url:  request.baseURL, resolvingAgainstBaseURL: false)!
        urlComponents.path = "\(urlComponents.path)\(request.path)"
        var urlRequest = URLRequest(url: urlComponents.url!)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.allHTTPHeaderFields
        urlRequest.httpBody = request.httpBody
        return urlRequest
    }
    
}


public extension Date {
    var currentTimeMillis : Int64 {
       let timeInterval: TimeInterval = self.timeIntervalSince1970
       let millisecond = Int64(round(timeInterval * 1000))
       return millisecond
    }
}


