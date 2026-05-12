//
//  AlamofireObjc.swift
//  QHFC
//
//  Alamofire wrapper for ObjC compatibility
//

import UIKit
import Alamofire

/// Network reachability status matching AFNetworkReachabilityStatus
@objc public enum AFNetworkReachabilityStatus: Int {
    case unknown = -1
    case notReachable = 0
    case reachableViaWWAN = 1
    case reachableViaWiFi = 2
}

/// Wrapper around Alamofire Request for ObjC cancel support
/// Since Alamofire creates URLSessionTask asynchronously, request.task is nil
/// immediately after session.request(). Use this wrapper to cancel via Request.cancel() directly.
@objcMembers
public class AFNetworkRequest: NSObject {
    private let request: Request
    private weak var manager: AlamofireObjc?

    init(request: Request, manager: AlamofireObjc) {
        self.request = request
        self.manager = manager
    }

    /// Cancel the request
    public func cancel() {
        request.cancel()
    }

    /// Whether the request has been cancelled
    public var isCancelled: Bool {
        return request.isCancelled
    }

    /// The underlying URLSessionTask (may be nil if task hasn't been created yet)
    public var task: URLSessionTask? {
        return request.task
    }
}

@objcMembers
public class AlamofireObjc: NSObject {
    
    public static let shared = AlamofireObjc()
    
    public var session: Session!
    public var reachabilityManager: NetworkReachabilityManager?
    public var reachabilityStatus: AFNetworkReachabilityStatus = .unknown
    
    /// Active requests tracking, keyed by request hash for cancel support
    private var activeRequests: [Int: AFNetworkRequest] = [:]
    private let requestLock = NSLock()
    
    public override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 60
        session = Session(configuration: configuration)
    }
    
    // MARK: - Request Tracking
    
    private func trackRequest(_ networkRequest: AFNetworkRequest) {
        requestLock.lock()
        defer { requestLock.unlock() }
        activeRequests[networkRequest.hash] = networkRequest
    }
    
    private func untrackRequest(_ networkRequest: AFNetworkRequest) {
        requestLock.lock()
        defer { requestLock.unlock() }
        activeRequests.removeValue(forKey: networkRequest.hash)
    }
    
    /// Cancel a specific AFNetworkRequest
    public func cancelRequest(_ request: AFNetworkRequest) {
        requestLock.lock()
        activeRequests.removeValue(forKey: request.hash)
        requestLock.unlock()
        request.cancel()
    }
    
    /// Cancel all active requests
    public func cancelAllRequests() {
        requestLock.lock()
        let requests = activeRequests.values
        activeRequests.removeAll()
        requestLock.unlock()
        requests.forEach { $0.cancel() }
    }
    
    // MARK: - POST with raw Data body (used for encrypted requests)
    
    @discardableResult
    public func post(_ urlString: String,
              bodyData: Data,
              headers: [String: String]?,
              success: @escaping (Data?) -> Void,
              failure: @escaping (Error) -> Void) -> AFNetworkRequest {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        var urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(url: urlString, method: .post, headers: httpHeaders)
        } catch {
            failure(error)
            // Return a placeholder request that does nothing on cancel
            let dummyRequest = session.request(URLRequest(url: URL(string: "about:blank")!))
            return AFNetworkRequest(request: dummyRequest, manager: self)
        }
        urlRequest.httpBody = bodyData
        urlRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        let dataRequest = session.request(urlRequest)
            .validate(statusCode: 200..<600)
        let networkRequest = AFNetworkRequest(request: dataRequest, manager: self)
        dataRequest.responseData { [weak self] response in
            self?.untrackRequest(networkRequest)
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(networkRequest)
        return networkRequest
    }
    
    // MARK: - POST with String body (used for SocialPost)
    
    @discardableResult
    public func post(_ urlString: String,
              bodyString: String,
              headers: [String: String]?,
              success: @escaping (Data?) -> Void,
              failure: @escaping (Error) -> Void) -> AFNetworkRequest {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        var urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(url: urlString, method: .post, headers: httpHeaders)
        } catch {
            failure(error)
            let dummyRequest = session.request(URLRequest(url: URL(string: "about:blank")!))
            return AFNetworkRequest(request: dummyRequest, manager: self)
        }
        urlRequest.httpBody = bodyString.data(using: .utf8)
        urlRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        let dataRequest = session.request(urlRequest)
            .validate(statusCode: 200..<600)
        let networkRequest = AFNetworkRequest(request: dataRequest, manager: self)
        dataRequest.responseData { [weak self] response in
            self?.untrackRequest(networkRequest)
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(networkRequest)
        return networkRequest
    }
    
    // MARK: - POST with dictionary parameters
    
    @discardableResult
    public func post(_ urlString: String,
              parameters: [String: Any]?,
              headers: [String: String]?,
              success: @escaping (Data?) -> Void,
              failure: @escaping (Error) -> Void) -> AFNetworkRequest {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        let dataRequest = session.request(urlString, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: httpHeaders)
            .validate(statusCode: 200..<600)
        let networkRequest = AFNetworkRequest(request: dataRequest, manager: self)
        dataRequest.responseData { [weak self] response in
            self?.untrackRequest(networkRequest)
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(networkRequest)
        return networkRequest
    }
    
    // MARK: - GET with parameters
    
    @discardableResult
    public func get(_ urlString: String,
             parameters: [String: Any]?,
             headers: [String: String]?,
             success: @escaping (Data?) -> Void,
             failure: @escaping (Error) -> Void) -> AFNetworkRequest {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        let dataRequest = session.request(urlString, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: httpHeaders)
            .validate(statusCode: 200..<600)
        let networkRequest = AFNetworkRequest(request: dataRequest, manager: self)
        dataRequest.responseData { [weak self] response in
            self?.untrackRequest(networkRequest)
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(networkRequest)
        return networkRequest
    }
    
    // MARK: - Network Reachability
    
    public var isReachable: Bool {
        return reachabilityManager?.isReachable ?? false
    }
    
    public func startMonitoring() {
        guard reachabilityManager == nil else { return }
        reachabilityManager = NetworkReachabilityManager()
        reachabilityManager?.startListening { [weak self] status in
            switch status {
            case .unknown:
                self?.reachabilityStatus = .unknown
            case .notReachable:
                self?.reachabilityStatus = .notReachable
            case .reachable(let type):
                switch type {
                case .ethernetOrWiFi:
                    self?.reachabilityStatus = .reachableViaWiFi
                case .cellular:
                    self?.reachabilityStatus = .reachableViaWWAN
                }
            }
        }
    }
    
    public func stopMonitoring() {
        reachabilityManager?.stopListening()
        reachabilityManager = nil
    }
    
    /// Start monitoring with status change callback (replaces AFNetworkReachabilityManager's block)
    public func startMonitoringWithStatusChange(_ statusChange: @escaping (AFNetworkReachabilityStatus) -> Void) {
        reachabilityManager = NetworkReachabilityManager()
        reachabilityManager?.startListening { status in
            switch status {
            case .unknown:
                statusChange(.unknown)
            case .notReachable:
                statusChange(.notReachable)
            case .reachable(let type):
                switch type {
                case .ethernetOrWiFi:
                    statusChange(.reachableViaWiFi)
                case .cellular:
                    statusChange(.reachableViaWWAN)
                }
            }
        }
    }
    
    /// Current reachability status
    public var currentReachabilityStatus: AFNetworkReachabilityStatus {
        return reachabilityStatus
    }
}
