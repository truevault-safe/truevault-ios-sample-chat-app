import Foundation
import UIKit


class ContactListTableViewController : UITableViewController {
    var highLevelClient: HighLevelClient!
    var user: User!
    var selectedContactUser: FullUser!
    var contacts: [FullUser] = []
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.refreshContacts()
    }
    
    func refreshContacts() {
        TrueVaultClient(accessToken: self.user.accessToken!).listUsers() { response in
            self.contacts = response.value!.users
            self.tableView.reloadData()
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.contacts.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "cell")
        let contact = self.contacts[indexPath.row]
        
        let name = contact.attributes["name"] as? String ?? contact.id
        
        cell.textLabel?.text = name
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        debugPrint("Viewing contact \(indexPath.row)")
        self.selectedContactUser = self.contacts[indexPath.row]
        self.performSegue(withIdentifier: "ViewConversationSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "ViewConversationSegue") {
            let dest = segue.destination as! ViewConversationViewController
            dest.contactUser = self.selectedContactUser
            dest.currentUser = self.user
            dest.highLevelClient = self.highLevelClient
        }
    }
}
