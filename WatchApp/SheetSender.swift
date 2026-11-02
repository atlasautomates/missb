import Foundation
import AuditModel

enum SheetSendResult: Equatable {
    case sent
    case unauthorized
    case unconfigured
    case failed
}

/// Posts one side's payload to the sheet endpoint. Apps Script web apps answer
/// with a redirect and cannot see an Authorization header, so the token rides
/// in the JSON body and a redirect keeps the POST. Modal's listener still
/// accepts the same body.
enum SheetSender {
    static func send(_ sheet: AuditSheet) async -> SheetSendResult {
        let urlString = ListenerConfig.url
        let token = ListenerConfig.token
        guard let url = URL(string: urlString),
              url.scheme == "https",
              !token.isEmpty else {
            return .unconfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 45
        do {
            let raw = try sheet.payloadJSON()
            var object = (try JSONSerialization.jsonObject(with: raw) as? [String: Any]) ?? [:]
            object["token"] = token
            request.httpBody = try JSONSerialization.data(withJSONObject: object)
            let redirect = PostRedirect()
            let session = URLSession(configuration: .ephemeral, delegate: redirect, delegateQueue: nil)
            defer { session.finishTasksAndInvalidate() }
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = object["ok"] as? Bool {
                if ok { return .sent }
                if (object["error"] as? String) == "unauthorized" { return .unauthorized }
                return .failed
            }
            if http.statusCode == 401 { return .unauthorized }
            if (200..<300).contains(http.statusCode) { return .sent }
            return .failed
        } catch {
            return .failed
        }
    }
}

/// Apps Script answers a POST with 302. URLSession would follow that as a GET
/// and drop the chart. This keeps the original method and body.
private final class PostRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let original = task.originalRequest else {
            completionHandler(request)
            return
        }
        var redirected = request
        redirected.httpMethod = original.httpMethod
        redirected.httpBody = original.httpBody
        if let type = original.value(forHTTPHeaderField: "Content-Type") {
            redirected.setValue(type, forHTTPHeaderField: "Content-Type")
        }
        if let auth = original.value(forHTTPHeaderField: "Authorization") {
            redirected.setValue(auth, forHTTPHeaderField: "Authorization")
        }
        completionHandler(redirected)
    }
}
