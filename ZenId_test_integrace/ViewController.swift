import RecogLib_iOS
import UIKit

class ViewController: UIViewController {
    let button = UIButton()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        ApplicationLogger.shared.enableRecognitionLogging()
        
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Start", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        button.setTitleColor(.blue, for: .normal)
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 48),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])

        button.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
    }

    @objc func buttonTapped() {
        ensureCredentials { [weak self] in
            let vc = PureFaceLivenessVerifierViewController()
            vc.delegate = self
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

extension ViewController: PureFaceLivenessVerifierDelegate {
    func completed(in viewController: PureFaceLivenessVerifierViewController) {
        navigationController?.popViewController(animated: true)
    }
}

extension ViewController {
    private func ensureCredentials(completion: (() -> Void)? = nil) {
        if Credentials.shared.isValid() {
            if let completion = completion {
                zenidAuthorize(completion: { _ in
                    DispatchQueue.main.async {
                        completion()
                    }
                })
            }
            return
        }

        let qrScannerController = QrScannerController()
        qrScannerController.delegate = self
        qrScannerController.successCompletion = completion
        qrScannerController.modalPresentationStyle = .overFullScreen
        present(qrScannerController, animated: false)
    }

    private func zenidAuthorize(completion: @escaping ((Bool) -> Void)) {
        let isAuthorized = ZenidSecurity.isAuthorized()
        print("ZenidSecurity: isAuthorized: \(String(isAuthorized))")

        if isAuthorized {
            completion(true)
            return
        }

        guard let challengeToken = ZenidSecurity.getChallengeToken() else {
            completion(false)
            print("unable to get challenge token")
            return
        }

        Task {
            do {
                let response = try await ApiClient(credentialsProvider: Credentials.shared)
                    .sendRequest(endpoint: .initSdk(token: challengeToken), responseModel: InitSdkResponse.self)

                guard let responseToken = response.Response else {
                    completion(false)
                    print("Failed to get response from API")
                    return
                }

                let authorized = ZenidSecurity.authorize(responseToken: responseToken)
                print("ZenidSecurity: authorized: \(String(authorized))")
                completion(authorized)

            } catch {
                print(error)
                completion(false)
            }
        }
    }
}

extension ViewController: QrScannerControllerDelegate {
    func qrSuccess(_ controller: UIViewController, scanDidComplete result: String, completion: (() -> Void)?) {
        if let qr = CredentialsQrCode(value: result), qr.isValid {
            Credentials.shared.update(apiURL: qr.apiURL!, apiKey: qr.apiKey!)

            if let completion = completion {
                zenidAuthorize(completion: { isAuthorized in
                    if !isAuthorized {
                        Credentials.shared.clear()
                    } else {
                        completion()
                    }
                })
            }
            print("Credentials updated, apiURL: \(Credentials.shared.apiURL?.absoluteString ?? ""), apiKey: \(Credentials.shared.apiKey ?? "")")
        }
    }

    func qrFail(_ controller: UIViewController, error: String) {
    }

    func qrCancel(_ controller: UIViewController) {
    }
}

extension URL {
    static let modelsFolder = Bundle.main.bundleURL.appendingPathComponent("Models")
    static let modelsDocuments = modelsFolder.appendingPathComponent("documents")
}
