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

@objcMembers
public class AlamofireObjc: NSObject {
    
    public static let shared = AlamofireObjc()
    
    private var session: Session!
    private var reachabilityManager: NetworkReachabilityManager?
    private var reachabilityStatus: AFNetworkReachabilityStatus = .unknown
    
    /// Active requests tracking, keyed by taskIdentifier for cancel support
    private var activeRequests: [Int: Request] = [:]
    private let requestLock = NSLock()
    
    public override init() {
        super.init()
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 60
        session = Session(configuration: configuration)
    }
    
    // MARK: - Request Tracking
    
    private func trackRequest(_ request: Request) {
        requestLock.lock()
        defer { requestLock.unlock() }
        guard let taskIdentifier = request.task?.taskIdentifier else { return }
        activeRequests[taskIdentifier] = request
    }
    
    private func untrackRequestByTaskIdentifier(_ taskIdentifier: Int) {
        requestLock.lock()
        defer { requestLock.unlock() }
        activeRequests.removeValue(forKey: taskIdentifier)
    }
    
    /// Cancel a specific request by its URLSessionTask
    public func cancelTask(_ task: URLSessionTask) {
        requestLock.lock()
        let request = activeRequests.removeValue(forKey: task.taskIdentifier)
        requestLock.unlock()
        request?.cancel()
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
              failure: @escaping (Error) -> Void) -> URLSessionTask? {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        var urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(url: urlString, method: .post, headers: httpHeaders)
        } catch {
            failure(error)
            return nil
        }
        urlRequest.httpBody = bodyData
        urlRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        let request = session.request(urlRequest)
            .validate(statusCode: 200..<600)
        request.responseData { [weak self] response in
            if let taskID = request.task?.taskIdentifier {
                self?.untrackRequestByTaskIdentifier(taskID)
            }
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(request)
        return request.task
    }
    
    // MARK: - POST with String body (used for SocialPost)
    
    @discardableResult
    public func post(_ urlString: String,
              bodyString: String,
              headers: [String: String]?,
              success: @escaping (Data?) -> Void,
              failure: @escaping (Error) -> Void) -> URLSessionTask? {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        var urlRequest: URLRequest
        do {
            urlRequest = try URLRequest(url: urlString, method: .post, headers: httpHeaders)
        } catch {
            failure(error)
            return nil
        }
        urlRequest.httpBody = bodyString.data(using: .utf8)
        urlRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        let request = session.request(urlRequest)
            .validate(statusCode: 200..<600)
        request.responseData { [weak self] response in
            if let taskID = request.task?.taskIdentifier {
                self?.untrackRequestByTaskIdentifier(taskID)
            }
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(request)
        return request.task
    }
    
    // MARK: - POST with dictionary parameters
    
    @discardableResult
    public func post(_ urlString: String,
              parameters: [String: Any]?,
              headers: [String: String]?,
              success: @escaping (Data?) -> Void,
              failure: @escaping (Error) -> Void) -> URLSessionTask? {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        let request = session.request(urlString, method: .post, parameters: parameters, encoding: URLEncoding.default, headers: httpHeaders)
            .validate(statusCode: 200..<600)
        request.responseData { [weak self] response in
            if let taskID = request.task?.taskIdentifier {
                self?.untrackRequestByTaskIdentifier(taskID)
            }
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(request)
        return request.task
    }
    
    // MARK: - GET with parameters
    
    @discardableResult
    public func get(_ urlString: String,
             parameters: [String: Any]?,
             headers: [String: String]?,
             success: @escaping (Data?) -> Void,
             failure: @escaping (Error) -> Void) -> URLSessionTask? {
        
        var httpHeaders: HTTPHeaders?
        if let h = headers, !h.isEmpty {
            httpHeaders = HTTPHeaders(h)
        }
        
        let request = session.request(urlString, method: .get, parameters: parameters, encoding: URLEncoding.default, headers: httpHeaders)
            .validate(statusCode: 200..<600)
        request.responseData { [weak self] response in
            if let taskID = request.task?.taskIdentifier {
                self?.untrackRequestByTaskIdentifier(taskID)
            }
            switch response.result {
            case .success(let data):
                success(data)
            case .failure(let error):
                if !error.isExplicitlyCancelledError {
                    failure(error)
                }
            }
        }
        trackRequest(request)
        return request.task
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
