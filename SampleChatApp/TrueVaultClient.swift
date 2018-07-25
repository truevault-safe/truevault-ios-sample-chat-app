import Foundation
import Alamofire

class User: ResponseObjectSerializable {
    let accessToken: String?
    let accountId: String;
    let id: String;
    let username: String;
    
    required convenience init?(response: HTTPURLResponse, representation: [String: Any]) {
        guard
            let user = representation["user"] as? [String: Any]
        else { return nil }
        
        self.init(dict: user)
    }
    
    required init?(dict: [String: Any]) {
        guard
            let id = dict["id"] as? String,
            let username = dict["username"] as? String,
            let accountId = dict["account_id"] as? String
            else { return nil }
        
        self.id = id
        self.username = username
        self.accountId = accountId
        self.accessToken = dict["access_token"] as? String
    }
}

class FullUser: User {
    let attributes: [String: Any]
    
    required init?(response: HTTPURLResponse, representation: [String: Any]) {
        guard
            let user = representation["user"] as? [String: Any],
            let attributes = user["attributes"] as? String
        else { return nil }
        
        self.attributes = try! decodeTrueVaultDocument(base64JSON: attributes)
        
        super.init(dict: user)
    }
    
    required init?(dict: [String: Any]) {
        if let attributes = dict["attributes"] as? String {
            self.attributes = try! decodeTrueVaultDocument(base64JSON: attributes)
        } else {
            self.attributes = [:]
        }
        
        
        super.init(dict: dict)
    }
}

struct Document: ResponseObjectSerializable {
    let documentId: String
    
    init?(response: HTTPURLResponse, representation: [String: Any]) {
        guard
            let documentId = representation["document_id"] as? String
        else { return nil }
        
        self.documentId = documentId
    }
}

struct FullDocument {
    let documentId: String
    let document: [String: Any]
    
    init(documentId: String, document: [String: Any]) {
        self.documentId = documentId
        self.document = document
    }
}

func decodeTrueVaultDocument(base64JSON: String) throws -> [String:Any] {
    let json = NSData(base64Encoded: base64JSON, options: [])!
    return try JSONSerialization.jsonObject(with: json as Data, options: .allowFragments) as! [String:Any]
}

struct DocumentList: ResponseObjectSerializable {
    let page: Int
    let perPage: Int
    let total: Int
    let documents: [FullDocument]
    
    init?(response: HTTPURLResponse, representation: [String: Any]) {
        guard
            let data = representation["data"] as? [String: Any],
            let page = data["page"] as? Int,
            let perPage = data["per_page"] as? Int,
            let total = data["total"] as? Int,
            let items = data["items"] as? [[String: Any]]
        else { return nil }
        
        self.page = page
        self.perPage = perPage
        self.total = total
        self.documents = items.map { item in
            let documentBase64 = item["document"] as! String
            let document = try! decodeTrueVaultDocument(base64JSON: documentBase64)
            return FullDocument(documentId: item["id"] as! String, document: document)
        }
    }
}

struct FullUserList: ResponseObjectSerializable {
    let users: [FullUser]
    
    init?(response: HTTPURLResponse, representation: [String: Any]) {
        guard
            let users = representation["users"] as? [[String: Any]]
        else { return nil }
        
        self.users = users.map { item in
            return FullUser(dict: item)!
        }
    }
}

struct DocumentMultiget: ResponseObjectSerializable {
    let documents: [FullDocument]
    
    init?(response: HTTPURLResponse, representation: [String: Any]) {
        guard
            let items = representation["documents"] as? [[String: Any]]
            else { return nil }
        
        self.documents = items.map { item in
            let documentBase64 = item["document"] as! String
            let document = try! decodeTrueVaultDocument(base64JSON: documentBase64)
            return FullDocument(documentId: item["id"] as! String, document: document)
        }
    }
    
    init(documents: [FullDocument]) {
        self.documents = documents
    }
}

enum TrueVaultRequestError: Error {
    case network(error: Error)
    case dataSerialization(error: Error)
    case TrueVaultError(code: Int?, message: String, type: String)
    case jsonSerialization(jsonObject: Any)
}

protocol ResponseObjectSerializable {
    init?(response: HTTPURLResponse, representation: [String: Any])
}

extension DataRequest {
    func responseObject<T: ResponseObjectSerializable>(queue: DispatchQueue? = nil, completionHandler: @escaping (DataResponse<T>) -> Void) {
        let responseSerializer = DataResponseSerializer<T> { request, response, data, error in
            guard error == nil else { return .failure(TrueVaultRequestError.network(error: error!)) }
            
            let jsonSerializer = DataRequest.jsonResponseSerializer(options: .allowFragments)
            let result = jsonSerializer.serializeResponse(request, response, data, nil)
            
            guard case let .success(jsonObj) = result, let jsonObject = jsonObj as? [String: Any] else {
                return .failure(TrueVaultRequestError.dataSerialization(error: result.error!))
            }
            
            // TODO: Handle non-200 responses that aren't TV error responses
            if jsonObject["result"] as? String == "error" {
                let error = jsonObject["error"] as? [String: Any]
                let code = error!["code"] as? Int
                let message = error!["message"] as! String
                let type = error!["type"] as! String
                return .failure(TrueVaultRequestError.TrueVaultError(code: code, message: message, type: type))
            }
            
            guard let response = response, let responseObject = T(response: response, representation: jsonObject) else {
                return .failure(TrueVaultRequestError.jsonSerialization(jsonObject: jsonObject))
            }
            
            return .success(responseObject)
        }
        
        response(queue: queue, responseSerializer: responseSerializer, completionHandler: completionHandler)
    }
}

public class TrueVaultClient {
    let accessToken: String
    
    init(accessToken: String) {
        self.accessToken = accessToken
    }
    
    class func login(accountId: String, username: String, password: String, notValidAfter: Date, completionHandler: @escaping ((DataResponse<User>) -> Void)) {
        let formattedDate = ISO8601DateFormatter.string(from: notValidAfter, timeZone: TimeZone.init(identifier: "UTC")!, formatOptions: [.withInternetDateTime, .withFractionalSeconds])

        
        Alamofire.request("https://api.truevault.com/v1/auth/login", method: .post, parameters: [
            "account_id": accountId,
            "username": username,
            "password": password,
            "not_valid_after": formattedDate
            ]).responseObject { (response: DataResponse<User>) in
                DispatchQueue.main.async {
                    completionHandler(response)
                }
        }
    }
    
    private func trueVaultRequest(path: String, method: HTTPMethod, parameters: [String: Any]) -> DataRequest {
        let authHeader = Request.authorizationHeader(user: self.accessToken, password: "")!
        let headers: HTTPHeaders = [authHeader.key: authHeader.value]
        
        return Alamofire.request("https://api.truevault.com/\(path)", method: method, parameters: parameters, headers: headers)
    }
    
    private func trueVaultRequestJSON<T: ResponseObjectSerializable>(path: String, method: HTTPMethod, parameters: [String: Any], completionHandler: @escaping ((DataResponse<T>) -> Void)) {
        trueVaultRequest(path: path, method: method, parameters: parameters).responseObject { (response: DataResponse<T>) in
                DispatchQueue.main.async {
                    completionHandler(response)
                }
            }
    }
    
    func createDocument(vaultId: String, document: [String: Any], completionHandler: @escaping ((DataResponse<Document>) -> Void)) {
        let documentJSON = try! JSONSerialization.data(withJSONObject: document, options: .init(rawValue: 0))
        let documentBase64 = documentJSON.base64EncodedString()
        
        trueVaultRequestJSON(path: "v1/vaults/\(vaultId)/documents", method: .post, parameters: ["document": documentBase64], completionHandler: completionHandler)
    }
    
    func listDocuments(vaultId: String, completionHandler: @escaping ((DataResponse<DocumentList>) -> Void)) {
        trueVaultRequestJSON(path: "v1/vaults/\(vaultId)/documents", method: .get, parameters: ["full": true, "per_page": 500], completionHandler: completionHandler)
    }
    
    func readUser(userId: String, completionHandler: @escaping ((DataResponse<FullUser>) -> Void)) {
        trueVaultRequestJSON(path: "v1/users/\(userId)", method: .get, parameters: ["full": true], completionHandler: completionHandler)
        
    }
    
    func listUsers(completionHandler: @escaping ((DataResponse<FullUserList>) -> Void)) {
        trueVaultRequestJSON(path: "v1/users", method: .get, parameters: ["full": true], completionHandler: completionHandler)
    }
    
    func getDocuments(vaultId: String, docIds: [String], completionHandler: @escaping ((DocumentMultiget?) -> Void)) {
        
        if docIds.count == 0 {
            completionHandler(DocumentMultiget(documents: []))
        } else if docIds.count == 1 {
            let docId = docIds.first!
            self.trueVaultRequest(path: "v1/vaults/\(vaultId)/documents/\(docId)", method: HTTPMethod.get, parameters: [:]).responseString { response in
                let decodedDocument = try! decodeTrueVaultDocument(base64JSON: response.value!)
                let fullDoc = FullDocument(documentId: docId, document: decodedDocument)
                completionHandler(DocumentMultiget(documents: [fullDoc]))
            }
            
        } else {
            let csvDocIds = docIds.joined(separator: ",")
        
            self.trueVaultRequestJSON(path: "v1/vaults/\(vaultId)/documents/\(csvDocIds)", method: .get, parameters: [:]) { response in
                completionHandler(response.result.value)
            }
        }
    }
    
    func createUser(accountId: String, username: String, password: String, attributes: [String: Any], groupIds: [String], completionHandler: @escaping ((DataResponse<FullUser>) -> Void)) {
        let attributesJSON = try! JSONSerialization.data(withJSONObject: attributes, options: .init(rawValue: 0))
        let attributesBase64 = attributesJSON.base64EncodedString()
        
        self.trueVaultRequestJSON(path: "v1/users?full=true", method: .post, parameters: [
            "username": username,
            "password": password,
            "attributes": attributesBase64,
            "group_ids": groupIds.joined(separator: ",")], completionHandler: completionHandler)
    }
}
