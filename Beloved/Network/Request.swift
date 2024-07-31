//
//  HttpClient.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation
import SwiftProtobuf

public protocol ResponseDataParser: AnyObject {
    
    func parse<R: Request>(request: R, data: Data) throws -> R.Response
}


public struct HTTPMethod: RawRepresentable, Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public static let get: HTTPMethod = "GET"
    public static let post: HTTPMethod = "POST"
    public static let patch: HTTPMethod = "PATCH"
    public static let put: HTTPMethod = "PUT"
    public static let delete: HTTPMethod = "DELETE"
    public static let options: HTTPMethod = "OPTIONS"
    public static let head: HTTPMethod = "HEAD"
    public static let trace: HTTPMethod = "TRACE"
}

/// Parameter types for `Request` objects.
public typealias Parameters = [String: Any?]
//public typealias Parameters = [String: Any]


public protocol Request  /*:@uncheckedSendable*/  {
    
    associatedtype Response: Sendable
    
    /// HTTP method, e.g. "GET".
    var method: HTTPMethod { get }
    
    var baseURL: URL { get }
    
    var path: String { get }
    
    var allHTTPHeaderFields: [String : String]? { get }
    
    var parameters: Parameters? { get }
    
    var httpBody: Data? { get }
    
    var dataParser: ResponseDataParser { get }
    

}

