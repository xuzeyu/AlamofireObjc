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

/// Completion handler typealias with named parameter for ObjC autocomplete
public typealias AFResponseCompletion = (_ response: AFResponseModel) -> Void

/// Unified response model for all network requests
@objcMembers
public class AFResponseModel: NSObject {
    /// Response data on success
    public var data: Data?
    /// Error info on failure
    public var error: Error?
    /// Whether request succeeded (error == nil)
    public var isSuccess: Bool { return error == nil }
    /// The network request that can be cancelled
    public private(set) var networkRequest: AFNetworkRequest?

    /// Lazily parsed JSON object (NSDictionary or NSArray), equivalent to AFNetworking's responseJSONObject
    /// Returns nil if data is nil or JSON parsing fails
    public var jsonObj: Any? {
        if let cached = _jsonObj { return cached }
        guard let data = data else { return nil }
        let parsed = try? JSONSerialization.jsonObject(with: data, options: [.mutableContainers])
        _jsonObj = parsed
        return parsed
    }
    private var _jsonObj: Any?

    /// Returns raw data as UTF-8 string
    public var jsonString: String? {
        guard let data = data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Convenience: returns json as NSDictionary (nil if not a dictionary)
    public var jsonDictionary: NSDictionary? {
        return jsonObj as? NSDictionary
    }

    init(data: Data? = nil, error: Error? = nil, networkRequest: AFNetworkRequest? = nil) {
        self.data = data
        self.error = error
        self.networkRequest = networkRequest
    }
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
              completion: @escaping AFResponseCompletion) -> AFNetworkRequest {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        var urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(url: urlString, method: .post, headers: httpHeaders)
        } catch {
            let dummyRequest = session.request(URLRequest(url: URL(string: "about:blank")!))
            let networkRequest = AFNetworkRequest(request: dummyRequest, manager: self)
            completion(AFResponseModel(error: error, networkRequest: networkRequest))
            return networkRequest
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
                completion(AFResponseModel(data: data, networkRequest: networkRequest))
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    completion(AFResponseModel(error: error, networkRequest: networkRequest))
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
              completion: @escaping AFResponseCompletion) -> AFNetworkRequest {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        var urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(url: urlString, method: .post, headers: httpHeaders)
        } catch {
            let dummyRequest = session.request(URLRequest(url: URL(string: "about:blank")!))
            let networkRequest = AFNetworkRequest(request: dummyRequest, manager: self)
            completion(AFResponseModel(error: error, networkRequest: networkRequest))
            return networkRequest
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
                completion(AFResponseModel(data: data, networkRequest: networkRequest))
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    completion(AFResponseModel(error: error, networkRequest: networkRequest))
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
              completion: @escaping AFResponseCompletion) -> AFNetworkRequest {
        
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
                completion(AFResponseModel(data: data, networkRequest: networkRequest))
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    completion(AFResponseModel(error: error, networkRequest: networkRequest))
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
             completion: @escaping AFResponseCompletion) -> AFNetworkRequest {
        
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
                completion(AFResponseModel(data: data, networkRequest: networkRequest))
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    completion(AFResponseModel(error: error, networkRequest: networkRequest))
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
