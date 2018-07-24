import UIKit
import Eureka

class LoginViewController: FormViewController {
    
    var username: String = ""
    var password: String = ""
    
    var user: User!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        form +++ Section("")
            <<< TextRow(){
                $0.title = "Username"
                $0.placeholder = "user@example.com"
                $0.onChange({self.username = $0.value ?? ""})
            }
            <<< PasswordRow(){
                $0.title = "Password"
                $0.onChange({self.password = $0.value ?? ""})
            }
            <<< ButtonRow(){
                $0.title = "Login"
                $0.onCellSelection({_, _ in self.login()})
            }
            +++ Section("")
            <<< ButtonRow(){
                $0.title = "Register"
                $0.onCellSelection({_, _ in self.register()})
            }
    }
    
    func login() {
        let notValidAfter = Date().addingTimeInterval(365 * 24 * 60 * 60)
        
        TrueVaultClient.login(accountId: TRUEVAULT_ACCOUNT_ID, username: self.username, password: self.password, notValidAfter: notValidAfter) { response in
            if response.result.isFailure {
                let alert = UIAlertController(title: nil, message: "Unable to login", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
                    alert.dismiss(animated: true)
                }))
                self.present(alert, animated: true)
                
            } else {
                self.user = response.value!
                self.performSegue(withIdentifier: "ViewContactsSegue", sender: self)
            }
        }
    }
    
    func register() {
        self.performSegue(withIdentifier: "RegisterSegue", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ViewContactsSegue" {
            let navController = segue.destination as! UINavigationController
            let vc = navController.topViewController! as! ContactListTableViewController
            vc.user = self.user
            vc.highLevelClient = HighLevelClient(chatServerEndpoint: CHAT_SERVER_ENDPOINT, accessToken: self.user.accessToken!, vaultId: VAULT_ID)
        }
    }
}

