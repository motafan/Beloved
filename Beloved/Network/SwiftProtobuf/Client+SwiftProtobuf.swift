//
//  Client+SwiftProtobuf.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation
import Combine
import SwiftProtobuf

public extension HttpClient {
    

    func send<T>(method: HTTPMethod = .post, 
                 keyPath: KeyPath<OSApiResponse, T>,
                 _ request: @Sendable () -> OSApiRequest) async throws -> T where T: SwiftProtobuf.Message, T: Sendable {
        let r = SwiftProtobufRequest(method: method, keyPath: keyPath, httpBodyRequest: request())
        return try await send(r)
    }
    
    
    func send<T>(method: HTTPMethod = .post, 
                 keyPath: KeyPath<OSApiResponse, T>,
                 _ request: () -> OSApiRequest) -> AnyPublisher<T, Error> where T: SwiftProtobuf.Message, T:  Sendable {
        let r = SwiftProtobufRequest(method: method, keyPath: keyPath, httpBodyRequest: request())
        return send(r)
    }
}
