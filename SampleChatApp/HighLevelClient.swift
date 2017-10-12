import Foundation

// This class handles splitting text out of a chat message when sending, and combining the information stored in TrueVault
// and the Node server when loading messages. In other words, it isolates the rest of the application from the complexity
// introduced by data bifurcation.
class HighLevelClient {
    let trueVaultClient: TrueVaultClient
    let chatServerClient: ChatServerClient
    let vaultId: String
    
    init(chatServerEndpoint: String, accessToken: String, vaultId: String) {
        self.trueVaultClient = TrueVaultClient(accessToken: accessToken)
        self.chatServerClient = ChatServerClient(chatServerEndpoint: chatServerEndpoint, accessToken: accessToken)
        self.vaultId = vaultId
    }
    
    func sendMessage(toUserId: String, message: String) {
        trueVaultClient.createDocument(vaultId: vaultId, document: ["message": message]) { trueVaultResponse in
            if trueVaultResponse.result.isSuccess {
                self.chatServerClient.createChatMessage(otherUserId: toUserId, truevaultVaultId: self.vaultId, truevaultDocId: trueVaultResponse.result.value!.documentId)
            } else {
                fatalError("Error creating TV document: \(trueVaultResponse.error.debugDescription)")
            }
        }
    }
    
    func getChatMessages(otherUserId: String, completionHandler: @escaping (([ChatAppMessage]) -> Void)) {
        self.chatServerClient.getChatMessages(otherUserId: otherUserId) { messages in
            let documentIds = messages.map { $0.trueVaultDocId }
            
            self.trueVaultClient.getDocuments(vaultId: self.vaultId, docIds: documentIds) { docs in
                if let docs = docs?.documents {
                    let chatAppMessages = messages.map { message -> ChatAppMessage in
                        let text = docs.first(where: { $0.documentId == message.trueVaultDocId })
                        return ChatAppMessage(id: message.trueVaultDocId, fromUserId: message.fromUserId, toUserId: message.toUserId, message: text?.document["message"] as! String)
                    }
                    
                    completionHandler(chatAppMessages)
                }
            }
            
            
        }
    }
}


struct ChatAppMessage {
    let id: String;
    let fromUserId: String;
    let toUserId: String;
    let message: String;
}
