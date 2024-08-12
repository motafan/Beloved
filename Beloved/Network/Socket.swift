//
//  HttpClient.swift
//  Beloved
//
//  Created by 风起兮 on 2024/7/29.
//

import Foundation
import Combine
import Starscream
import Connectivity


extension Socket {
    
    public enum ConnectionState: Sendable {
        case idle
        case connecting(times: Int)
        case initialized
        case initializeFailed(message: String)
        case waitingForNetwork
        case waitingForReconnect(times: Int)
        case closing
        case closed(reason: String)
    }
    
}

extension Socket.ConnectionState: Equatable {
    
    public static func == (lhs: Socket.ConnectionState, rhs: Socket.ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.connecting, .connecting):
            return true
        case (.initialized, .initialized):
            return true
        case (.initializeFailed, .initializeFailed):
            return true
        case (.waitingForNetwork, .waitingForNetwork):
            return true
        case (.waitingForReconnect, .waitingForReconnect):
            return true
        case (.closing, .closing):
            return true
        case (.closed, .closed):
            return true
        default:
            return false
        }
    }
}


fileprivate extension Socket {
    
    struct ResponseHandler {
        
        let closure: Completion
    }
    
}


public extension Socket {
    
    func send<T>(keyPath: KeyPath<STResponse, T>, configure: @Sendable (inout STRequest) -> Void) async throws -> T {
        let response = try await send(configure: configure)
        return response[keyPath: keyPath]
    }
}


internal typealias Completion = @MainActor @Sendable (_ result: Swift.Result<STResponse, Error>) -> Void

final public class Socket: @unchecked Sendable {
    
    public private(set) var state: Socket.ConnectionState = .idle
    
    public static let shared  = Socket()
    
    private let connectivity: Connectivity = Connectivity()
    
    private var webSocket: WebSocket?
    
    private var serverURL: URL!
    private var token: String?
    private var userID: String?
    
    
    private var sendPingTimer: Timer?
    private var pingTimes: Int = 0
    
    private let propertyQueue = DispatchQueue(label: "com.source.Socket.DelegateQueue")
    
    private var contextID: Int32 = 0
    fileprivate var pendingRequest = [Int32: ResponseHandler]()
    
    public func setup(socketServer: String, token: String, userID: String) {
        
        let uri = socketServer.replacingOccurrences(of: "${login_token}", with: token)
        guard let url = URL(string: uri) else { return  }
        
        self.serverURL = url
        self.token = token
        self.userID = userID
    }
    
    public func connect() {
        startNotifier()
        tryConnect()
    }
    
    public func disconnect() {
        self.webSocket?.disconnect()
        self.webSocket = nil
        self.state = .closed(reason: "")
        token = nil
        userID = nil
    }
    
    @available(*, renamed: "send(configure:)")
    private func send(configure: (inout STRequest) -> Void, completion:  @escaping Completion) {
        
        guard let webSocket = self.webSocket else {
            Task { @MainActor in
                completion(.failure(URLError(.cannotConnectToHost)))
            }
            return
        }
        
        let context = propertyQueue.sync {
            contextID += 1
            return contextID
        }
        
        Task { @MainActor in
            try await Task.sleep(nanoseconds: 5 * NSEC_PER_SEC)
            if let handler = self.propertyQueue.sync(execute: {self.pendingRequest.removeValue(forKey: context)}) {
                handler.closure(.failure(URLError(.timedOut)))
            }
        }
        
        propertyQueue.sync {
            pendingRequest[context]  = ResponseHandler(closure: completion)
        }
        
        let version: Int32 = 1
        
        var request = STRequest()
        configure(&request)
        request.context = context
        request.token = token ?? ""
        request.time = Int64(Date().timeIntervalSince1970 * 1000)
        request.version = version
        request.version = 1
        switch request.message.body {
        case .sendChatMessage, .loadChatRecord, .sendChatMessageReceipt:
            request.id = .chatMessage
        default:
            break
        }
        request.sign = "\(request.id.rawValue)\(version)\(context)\(token != nil ? token! + userID! : "DefaultSalt")".md5
        
        var stream = Data(count: 16)
        let stride =  MemoryLayout<UInt16>.stride
        // 头长度
        stream.storeBytes(of: UInt16(16), toByteOffset: 0)
        // 头版本
        stream.storeBytes(of: UInt16(0), toByteOffset: 1 * stride)
        // 加密算法， 0 不加密， 1 AES加密， 2： RSA 加密
        stream.storeBytes(of: UInt16(1), toByteOffset: 2 * stride)
        // 压缩算法
        stream.storeBytes(of: UInt16(0), toByteOffset: 3 * stride)
        // 8字节预留
        let encodeData = Crypto.encode(data: try! request.serializedData()) ?? Data()
        stream.append(encodeData) // 写入加密后的数据
        
        webSocket.write(data: stream)
        
    }
    
    public func send(configure: @Sendable (inout STRequest) -> Void) async throws -> STResponse {
        return try await withCheckedThrowingContinuation { continuation in
            send(configure: configure) { result in
                continuation.resume(with: result)
            }
        }
    }
        
    private func startNotifier() {
        if connectivity.whenConnected == nil {
            let connectivityChanged: (Connectivity) -> Void = { [weak self] connectivity in
                if connectivity.status != .notConnected {
                    self?.tryConnect()
                }
            }
            
            connectivity.whenConnected = connectivityChanged
            connectivity.whenDisconnected = connectivityChanged
            connectivity.startNotifier()
        }
    }
    
    
    private func tryConnect() {
        
        if connectivity.status != .notConnected {
            let oldState = state
            if case .idle = oldState {
                self.webSocket = createSocket()
                self.webSocket?.connect()
                self.state = .connecting(times: 5)
            } else if case .closed = oldState {
                self.webSocket = createSocket()
                self.webSocket?.connect()
                self.state = .connecting(times: 5)
            } else if case .waitingForNetwork = oldState {
                if connectivity.status != .notConnected {
                    webSocket = createSocket()
                    webSocket?.connect()
                    state = .connecting(times: 5)
                }
            } else if case .waitingForReconnect(let times) = oldState {
                self.webSocket = createSocket()
                self.webSocket?.connect()
                self.state = .connecting(times: times - 1)
            }
        }
    }
    
    
    private func createSocket() -> WebSocket {
        let socket = WebSocket(request: URLRequest(url: serverURL, timeoutInterval: 5))
        socket.delegate = self
        
        return socket
    }
}

extension Socket {
    
    private func startPing() {
        let interval: TimeInterval = 5
        let t = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(sendPing), userInfo: nil, repeats: true)
        RunLoop.current.add(t, forMode: .common)
        t.fire()
        self.sendPingTimer = t
    }
    
    private func stopPing() {
        self.sendPingTimer?.invalidate()
        self.sendPingTimer = nil
    }
    
    @objc private func sendPing() {
        
        guard state == .initialized else {
            return
        }
        
        self.pingTimes += 1
        if self.pingTimes % 4 == 0 {
            self.webSocket?.write(ping: Data())
        }
    }
}

extension Socket: WebSocketDelegate {
    
    private func handle(connectionState newState: Socket.ConnectionState) {
        Task {
            self.state = newState
            if case .initialized = newState {
                self.startPing()
            } else if case .waitingForNetwork = newState {
                if connectivity.status != .notConnected {
                    tryConnect()
                }
            } else if case .waitingForReconnect = newState {
                if connectivity.status != .notConnected {
                    
                    try await Task.sleep(nanoseconds: UInt64.random(in: 1...4) * NSEC_PER_SEC)
                    tryConnect()
                    
                }
            } else if case .closed = newState {
                self.stopPing()
                if connectivity.status != .notConnected {
                    tryConnect()
                }
            } else if case .initialized = newState {
                
            }
        }
    }
    
    private func onClose(reason: String) {
        switch (state, connectivity.status) {
        case (_, .notConnected):
            handle(connectionState: .waitingForNetwork)
        case (.connecting(let times), _) where times > 0 && self.connectivity.status != .notConnected:
            self.handle(connectionState: .waitingForReconnect(times: times))
        default:
            self.handle(connectionState: .closed(reason: reason))
        }
    }
    
    func onMessage(data: Data) {
        guard data.count >= 16 else { return }
        
        let stride = MemoryLayout<UInt16>.stride
        
        let length = data.load(fromByteOffset: 0, as: UInt16.self)
        let version = data.load(fromByteOffset: 1 * stride, as: UInt16.self)
        let encryptMethod = data.load(fromByteOffset: 2 * stride, as: UInt16.self)
        let compress = data.load(fromByteOffset: 3 * stride, as: UInt16.self)
        
        guard length < data.count, version == 0, compress == 0 else { return }
        switch encryptMethod {
        case 0: // 无加密
            if let response = try? STResponse(serializedBytes: data.dropFirst(Int(length))) {
                processResonse(response)
            }
        case 1: // 有加密，需要解密
            if  let decoded = Crypto.decode(data: data.dropFirst(Int(length))),
                let resopnse = try? STResponse(serializedBytes: decoded) {
                processResonse(resopnse)
            }
        default: return
        }
    }
    
    
    private func processResonse(_ response: STResponse) {
        Task { @MainActor in
            switch response.id {
            default:
                guard let handler = propertyQueue.sync(execute: { pendingRequest.removeValue(forKey: response.context) }) else {
                    return
                }
                
                if(response.code == 0) {
                    handler.closure(.success(response))
                } else {
                    handler.closure(.failure(URLError(.init(rawValue: Int(response.code)), userInfo: [NSURLErrorDomain : response.message])))
                }
            }
        }
        
    }
    
    nonisolated public func didReceive(event: Starscream.WebSocketEvent, client: Starscream.WebSocketClient) {
        switch event {
        case .connected:
            handle(connectionState: .initialized)
        case .disconnected(let string, _):
            onClose(reason: string)
        case .binary(let data):
            onMessage(data: data)
        case .text:
            break
        case .pong:
            break
        case .ping:
            break
        case .error(let error):
            onClose(reason: error?.localizedDescription ?? "")
        case .viabilityChanged(let viability):
            if !viability {
                onClose(reason: "Viability changed")
            }
        case .reconnectSuggested(let reconnect):
            if reconnect  {
                onClose(reason: "Reconnect suggested")
            }
        case .cancelled:
            break
        case .peerClosed:
            onClose(reason: "Peer closed")
        }
        
    }
    
}
