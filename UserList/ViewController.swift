import Cocoa
import CoreData

struct UserInformation {
    var id: Int64
    var username: String
    var email: String
    var isEnabled: Bool
}

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource {

    @IBOutlet weak var topBarView: NSView!
    @IBOutlet weak var newUserButton: NSButton!
    @IBOutlet weak var hideDisabledUserButton: NSButton!
    @IBOutlet weak var saveUserButton: NSButton!
    @IBOutlet weak var deleteUserButton: NSButton!
    @IBOutlet weak var newUserView: NSView!
    @IBOutlet weak var newUserTopView: NSView!
    @IBOutlet weak var usernameTextField: NSTextField!
    @IBOutlet weak var displayNameTextField: NSTextField!
    @IBOutlet weak var phoneTextField: NSTextField!
    @IBOutlet weak var emailTextField: NSTextField!
    @IBOutlet weak var enabledButton: NSButton!
    @IBOutlet weak var rolesComboBox: NSComboBox!
    @IBOutlet weak var tableView: NSTableView!

    var users = [UserInformation]()
    var filteredUsers = [UserInformation]()
    var hideDisabledUsers = false
    
    let appDelegate = NSApplication.shared.delegate as! AppDelegate
    lazy var context = appDelegate.persistentContainer.viewContext

    override func viewDidLoad() {
        super.viewDidLoad()
        getUserInformation()
        tableView.dataSource = self
        tableView.delegate = self
        topBarView.wantsLayer = true
        topBarView.layer?.backgroundColor = NSColor.darkGray.cgColor
        newUserTopView.wantsLayer = true
        newUserTopView.layer?.backgroundColor = NSColor.darkGray.cgColor
        newUserView.alphaValue = 0.0
        deleteUserButton.isEnabled = false
        saveUserButton.isEnabled = false
        updateFilteredData()
    }

    // MARK: Table View Functions
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredUsers.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let columnIdentifier = tableColumn?.identifier else { return nil }
        let cellIdentifier = columnIdentifier.rawValue
        let cell = tableView.makeView(withIdentifier: columnIdentifier, owner: self) as? NSTableCellView

        switch cellIdentifier {
        case "idColumn":
            cell?.textField?.stringValue = String(filteredUsers[row].id)
        case "usernameColumn":
            cell?.textField?.stringValue = filteredUsers[row].username
        case "emailColumn":
            cell?.textField?.stringValue = filteredUsers[row].email
        case "isEnabledColumn":
            cell?.textField?.stringValue = filteredUsers[row].isEnabled ? "Yes" : "No"
        default:
            cell?.textField?.stringValue = ""
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRowCount = tableView.numberOfSelectedRows
        deleteUserButton.isEnabled = selectedRowCount > 0
    }

    // MARK: Save User Information to Core Data
    func saveUserInformation() {
        let newUser = NSEntityDescription.insertNewObject(forEntityName: "User", into: context)
        newUser.setValue(giveID(), forKey: "id")
        newUser.setValue(usernameTextField.stringValue, forKey: "username")
        newUser.setValue(displayNameTextField.stringValue, forKey: "displayName")
        newUser.setValue(phoneTextField.stringValue, forKey: "phone")
        newUser.setValue(emailTextField.stringValue, forKey: "email")
        newUser.setValue(enabledButton.state == .on ? true : false, forKey: "isEnabled")
        newUser.setValue(rolesComboBox.stringValue, forKey: "roles")
        do {
            try context.save()
            print("Saved!")
        } catch {
            print("Not Saved!")
        }
        getUserInformation()
    }

    // MARK: Get User Information
    func getUserInformation() {
        users.removeAll()

        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        fetchRequest.returnsObjectsAsFaults = false

        do {
            let results = try context.fetch(fetchRequest)
            for result in results as! [NSManagedObject] {
                if let id = result.value(forKey: "id") as? Int64,
                   let username = result.value(forKey: "username") as? String,
                   let email = result.value(forKey: "email") as? String,
                   let isEnabled = result.value(forKey: "isEnabled") as? Bool {
                    users.append(UserInformation(id: id, username: username, email: email, isEnabled: isEnabled))
                }
            }
        } catch {
            print("Fail to Get Data")
        }
        updateFilteredData()
    }

    // MARK: Update Enabled User
    func updateFilteredData() {
        filteredUsers = hideDisabledUsers ? users.filter { $0.isEnabled } : users
        tableView.reloadData()
    }

    // MARK: New User Button Clicked
    @IBAction func newUserButtonClicked(_ sender: Any) {
        newUserView.alphaValue = 1.0
        saveUserButton.isEnabled = true
    }

    // MARK: Save Button Clicked
    @IBAction func saveUserButtonClicked(_ sender: Any) {
        if usernameTextField.stringValue.isEmpty || displayNameTextField.stringValue.isEmpty || phoneTextField.stringValue.isEmpty || emailTextField.stringValue.isEmpty || rolesComboBox.stringValue.isEmpty {
            let alert = NSAlert()
            alert.messageText = "Warning"
            alert.informativeText = "Please fill in all fields."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            saveUserInformation()
            newUserView.alphaValue = 0.0
            saveUserButton.isEnabled = false
            usernameTextField.stringValue = ""
            displayNameTextField.stringValue = ""
            phoneTextField.stringValue = ""
            emailTextField.stringValue = ""
            rolesComboBox.stringValue = ""
        }
    }

    // MARK: Hide Disabled User
    @IBAction func hideDisabledUser(_ sender: Any) {
        hideDisabledUsers.toggle()
        updateFilteredData()
    }

    // MARK: Delete Functions
    @IBAction func deleteUserClicked(_ sender: Any) {
        let alert = NSAlert()
        alert.messageText = "Delete User"
        alert.informativeText = "Are you sure you want to delete the selected user?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            deleteSelectedRows()
        }
        deleteUserButton.isEnabled = false
    }

    func deleteData(withID id: Int64) {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        fetchRequest.predicate = NSPredicate(format: "id == %d", id)

        do {
            let results = try context.fetch(fetchRequest)
            for result in results as! [NSManagedObject] {
                context.delete(result)
            }
            try context.save()
        } catch {
            print("Failed to delete record: \(error)")
        }
    }

    func deleteSelectedRows() {
        let selectedRowIndexes = tableView.selectedRowIndexes

        selectedRowIndexes.reversed().forEach { index in
            let idToDelete = filteredUsers[index].id
            deleteData(withID: idToDelete)
            if let originalIndex = users.firstIndex(where: { $0.id == idToDelete }) {
                users.remove(at: originalIndex)
            }
        }
        updateFilteredData()
    }

    // MARK: Give a Random ID
    func giveID() -> Int {
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "User")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: true)]

        do {
            let results = try context.fetch(fetchRequest)
            var nextID: Int = 1
            var existingIDs: Set<Int> = []

            for result in results {
                if let id = result.value(forKey: "id") as? Int {
                    existingIDs.insert(id)
                }
            }
            while existingIDs.contains(nextID) {
                nextID += 1
            }
            return nextID
        } catch {
            print("Error fetching users: \(error)")
            return 1
        }
    }
}
