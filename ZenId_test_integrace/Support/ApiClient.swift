import Foundation

enum ApiError: Error {
    case wrongRequest
    case parsingError
    case unauthorized
    case notResults
    case serverError(code: Int)
    case unknown
}

struct Endpoint {
    enum RequestType: String {
        case get = "GET"
        case post = "POST"
    }

    let path: String
    let requestType: RequestType
    let parameters: [String: Any]?
    let headers: [String: Any]?

    init(path: String, requestType: RequestType = .get, parameters: [String: Any]? = nil, headers: [String: Any]? = nil) {
        self.path = path
        self.requestType = requestType
        self.parameters = parameters
        self.headers = headers
    }

    func createHeaders() -> [String: Any] {
        var headers: [String: Any] = ["Content-Type": "application/json"]
        if let additionalHeaders = self.headers {
            for header in additionalHeaders {
                headers[header.key] = header.value
            }
        }
        return headers
    }
}

extension Endpoint {
    static func initSdk(token: String) -> Endpoint {
        Endpoint(path: "initSdk", parameters: ["token": token])
    }
}

protocol CredentialsProvider {
    var apiURL: URL? { get }
    var apiKey: String? { get }
}

class ApiClient {
    private let credentialsProvider: CredentialsProvider
    private let configuration: URLSessionConfiguration

    init(credentialsProvider: CredentialsProvider) {
        self.credentialsProvider = credentialsProvider

        guard let apiKey = credentialsProvider.apiKey, !apiKey.isEmpty else {
            fatalError("Missing API key.")
        }
        guard let apiURL = credentialsProvider.apiURL else {
            fatalError("Missing or malformed API URL!")
        }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 600
        configuration.timeoutIntervalForResource = 600

        let cookie = HTTPCookie(
            properties: [
                HTTPCookiePropertyKey.name: "api_key",
                HTTPCookiePropertyKey.value: apiKey,
                HTTPCookiePropertyKey.originURL: apiURL,
                HTTPCookiePropertyKey.path: apiURL.path,
            ]
        )

        if let cookie {
            configuration.httpCookieStorage?.setCookie(cookie)
        }
        self.configuration = configuration
    }

    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type) async throws -> T {
        guard let baseURL = credentialsProvider.apiURL else {
            fatalError("Missing or malformed API URL!")
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            fatalError("Missing or malformed API URL!")
        }
        components.percentEncodedQueryItems = Self.formatQueryItems(parameters: endpoint.parameters)

        guard let url = components.url else {
            fatalError("Missing or malformed API URL!")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.cachePolicy = .returnCacheDataElseLoad
        urlRequest.httpMethod = endpoint.requestType.rawValue

        if endpoint.requestType != .get, let parameters = endpoint.parameters {
            urlRequest.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }

        // Sets the headers for the request.
        endpoint.createHeaders().forEach { key, value in
            if let value = value as? String {
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }

        let (data, response) = try await URLSession.shared.data(for: urlRequest, delegate: nil)
        guard let response = response as? HTTPURLResponse else {
            throw ApiError.notResults
        }
        switch response.statusCode {
        case 200 ... 299:
            guard let decodedResponse = try? JSONDecoder().decode(responseModel, from: data) else {
                throw ApiError.parsingError
            }
            return decodedResponse
        case 401:
            throw ApiError.unauthorized
        default:
            throw ApiError.serverError(code: response.statusCode)
        }
    }

    private class func formatQueryItem(key: String, value: Any) -> [URLQueryItem] {
        if let array = value as? [Any] {
            return array.map { URLQueryItem(name: key, value: "\($0)") }
        }
        return [URLQueryItem(name: key, value: "\(value)")]
    }

    private class func formatQueryItems(parameters: [String: Any]?) -> [URLQueryItem] {
        guard let allParams = parameters else { return [] }
        return allParams
            .flatMap { return formatQueryItem(key: $0.key, value: $0.value) }
            .compactMap { $0 }
    }
}

struct InitSdkResponse: Decodable {
    var Response: String?
    var ErrorCode: String?
    var ErrorText: String?
    var MessageType: String?
}
