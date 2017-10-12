import Foundation
import Alamofire

struct ChatServerMessage {
    let fromUserId: String;
    let toUserId: String;
    let trueVaultVaultId: String;
    let trueVaultDocId: String;
}

class ChatServerClient {
    private let chatServerEndpoint: String
    private let accessToken: String;
    
    init(chatServerEndpoint: String, accessToken: String) {
        self.chatServerEndpoint = chatServerEndpoint
        self.accessToken = accessToken
    }
    
    func getChatMessages(otherUserId: String, callback: @escaping (([ChatServerMessage]) -> Void)) {
        let authHeader = Request.authorizationHeader(user: self.accessToken, password: "")!
        let headers: HTTPHeaders = [authHeader.key: authHeader.value]
        
        Alamofire.request("\(self.chatServerEndpoint)/chat/\(otherUserId)/messages", headers: headers).validate().responseJSON() { response in
            if let json = response.result.value {
                let responseDict = json as! Dictionary<String, Any>
                let messages = responseDict["messages"] as! [Dictionary<String, Any>]
                let chatServerMessages = messages.map { ChatServerMessage(fromUserId: $0["fromUserId"] as! String, toUserId: $0["toUserId"] as! String, trueVaultVaultId: $0["truevaultVaultId"] as! String, trueVaultDocId: $0["truevaultDocId"] as! String) }
                
                callback(chatServerMessages)
            } else {
                fatalError("Error loading chat messages: \(response.error.debugDescription)")
            }
        }
    }
    
    func createChatMessage(otherUserId: String, truevaultVaultId: String, truevaultDocId: String) {
        let authHeader = Request.authorizationHeader(user: self.accessToken, password: "")!
        let headers: HTTPHeaders = [authHeader.key: authHeader.value]
        
        let parameters = [
            "truevaultVaultId": truevaultVaultId,
            "truevaultDocId": truevaultDocId
        ]
        
        Alamofire.request("\(CHAT_SERVER_ENDPOINT)/chat/\(otherUserId)/messages",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers).validate(statusCode: 201...201).response() { response in
                if let error = response.error {
                    fatalError("Error creating message: \(error.localizedDescription)")
                }
        }
    }
}
