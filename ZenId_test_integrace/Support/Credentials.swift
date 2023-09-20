import Foundation

final class Credentials {
    private let apiURLKey = "apiURL"
    private let apiKeyKey = "apiKey"
    
    public static let shared = Credentials()
    
    var apiURL: URL? {
        get {
            guard let value = UserDefaults.standard.string(forKey: apiURLKey) else { return nil }
            return URL(string: value)
        }
    }
    
    var apiKey: String? {
        get { return  UserDefaults.standard.string(forKey: apiKeyKey) }
    }

    private init() {}
    
    public func update(apiURL: URL, apiKey: String) {
        UserDefaults.standard.setValue(apiURL.absoluteString, forKey: apiURLKey)
        UserDefaults.standard.setValue(apiKey, forKey: apiKeyKey)
    }
    
    public func clear() {
        UserDefaults.standard.removeObject(forKey: apiURLKey)
        UserDefaults.standard.removeObject(forKey: apiKeyKey)
    }
    
    public func isValid() -> Bool {
        guard
            let apiKey = apiKey, !apiKey.isEmpty else {
            return false
        }
        guard
            let _ = apiURL else {
            return false
        }
        
        return true
    }
}

extension Credentials: CredentialsProvider {}
