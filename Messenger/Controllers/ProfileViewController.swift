//
//  ProfileViewController.swift
//  Messenger
//
//  Created by Николай Никитин on 28.04.2022.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import SDWebImage

final class ProfileViewController: UIViewController {
  //MARK: - Properties
  var data = [ProfileViewModel]()

  //MARK: - Outlets
  @IBOutlet var tableView: UITableView!

  //MARK: - View Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    data.append(ProfileViewModel(viewModelType: .info, title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")", hendler: nil))
    data.append(ProfileViewModel(viewModelType: .info, title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")", hendler: nil))
    data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", hendler: { [weak self] in
      guard let strongSelf = self else { return }
      let actionSheet = UIAlertController(title: "", message: "", preferredStyle: .actionSheet)
      actionSheet.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { [weak self] _ in
        guard let strongSelf = self else { return }
        UserDefaults.standard.set(nil, forKey: "email")
        UserDefaults.standard.set(nil, forKey: "name")
        //LogOut Facebook
        FBSDKLoginKit.LoginManager().logOut()
        //LogOut Google
        GIDSignIn.sharedInstance.signOut()

        do {
          try FirebaseAuth.Auth.auth().signOut()
          let vc = LoginViewController()
          let nav = UINavigationController(rootViewController: vc)
          nav.modalPresentationStyle = .fullScreen
          strongSelf.present(nav, animated: true)
        }
        catch {
          print("Failed to log out!")
        }
      }))
      actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
      strongSelf.present(actionSheet, animated: true)
    }))
    tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
    tableView.delegate = self
    tableView.dataSource = self
    tableView.tableHeaderView = createTableHeader()
  }

  //MARK: - Methods
  func createTableHeader() -> UIView? {
    guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return nil }
    let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
    let filename = safeEmail + "_profile_picture.png"
    let path = "images/" + filename
    let headerView = UIView(frame: CGRect(x: 0,
                                          y: 0,
                                          width: self.view.width,
                                          height: 300))
    headerView.backgroundColor = .link
    let imageView = UIImageView(frame: CGRect(x: (headerView.width - 150)/2,
                                              y: 75,
                                              width: 150,
                                              height: 150))

    imageView.contentMode = .scaleAspectFit
    imageView.backgroundColor = .white
    imageView.layer.borderColor = UIColor.white.cgColor
    imageView.layer.borderWidth = 3
    imageView.layer.masksToBounds = true
    imageView.layer.cornerRadius = imageView.width / 2
    headerView.addSubview(imageView)

    StorageManager.shared.downloadURL(for: path) { result in
      switch result {
      case .success(let url):
        imageView.sd_setImage(with: url, completed: nil)
      case .failure(let error):
        print("Failed to get download URL - \(error)")
      }
    }

    return headerView
  }
}

//MARK: - UITableViewDelegate, UITableViewDataSource
extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return data.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let viewModel = data[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
    cell.setUp(with: viewModel)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    data[indexPath.row].hendler?()
  }
}

//MARK: - ProfileTableViewCell class
class ProfileTableViewCell: UITableViewCell {

  //MARK: - ProfileTableViewCell Properties
  static let identifier = "ProfileTableViewCell"

  //MARK: - ProfileTableViewCell Methods
  public func setUp(with viewModel: ProfileViewModel) {
    self.textLabel?.text = viewModel.title
    switch viewModel.viewModelType {
    case .info:
      textLabel?.textAlignment = .left
      selectionStyle = .none
    case .logout:
      textLabel?.textColor = .red
      textLabel?.textAlignment = .center
    }
  }
}
