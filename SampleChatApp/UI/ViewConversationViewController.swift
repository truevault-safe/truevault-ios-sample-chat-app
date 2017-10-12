import UIKit
import MessageKit

struct ChatUIMessage: MessageType {
    var sender: Sender
    
    var messageId: String
    
    var sentDate: Date
    
    var data: MessageData
}

class ViewConversationViewController: MessagesViewController, MessageInputBarDelegate, MessagesDataSource, MessagesDisplayDelegate {
    
    var highLevelClient: HighLevelClient!
    var currentUser: User!
    var contactUser: FullUser!
    var messages: [ChatAppMessage]?
    
    func currentSender() -> Sender {
        return Sender(id: self.currentUser.id, displayName: "")
    }
    
    func messageForItem(at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageType {
        let message = self.messages![indexPath.section]
        return ChatUIMessage(sender: Sender(id: message.fromUserId, displayName: ""), messageId: message.id, sentDate: Date(), data: MessageData.text(message.message))
    }
    
    func numberOfMessages(in messagesCollectionView: MessagesCollectionView) -> Int {
        return self.messages?.count ?? 0
    }
    
    func messageStyle(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> MessageStyle {
        let corner: MessageStyle.TailCorner = isFromCurrentSender(message: message) ? .bottomRight : .bottomLeft
        return .bubbleTail(corner, .curved)
    }
    
    func textColor(for message: MessageType, at indexPath: IndexPath, in messagesCollectionView: MessagesCollectionView) -> UIColor {
        return isFromCurrentSender(message: message) ? .white : .darkText
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        messagesCollectionView.messagesDataSource = self
        messagesCollectionView.messagesDisplayDelegate = self
        messageInputBar.delegate = self
        
        highLevelClient.getChatMessages(otherUserId: self.contactUser.id) { messages in
            self.messages = messages
         
            self.messagesCollectionView.reloadData()
        }
    }
    
    func messageInputBar(_ inputBar: MessageInputBar, didPressSendButtonWith text: String) {
        
        highLevelClient.sendMessage(toUserId: self.contactUser.id, message: text)
        
        debugPrint("Sent message \(text)")
        inputBar.inputTextView.text = ""
        
        self.messages!.append(ChatAppMessage(id: UUID().uuidString, fromUserId: self.currentUser.id, toUserId: self.contactUser.id, message: text))
        
        messagesCollectionView.reloadData()
    }
    
    
}
