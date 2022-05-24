//
//  ConversationsViewController.swift
//  Messenger
//
//  Created by Николай Никитин on 28.04.2022.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

struct Conversation {
  let id: String
  let name: String
  let otherUserEmail: String
  let latestMessage: LatestMessage
}

struct LatestMessage {
  let date: String
  let text: String
  let isRead: Bool
}

class ConversationsViewController: UIViewController {

  //MARK: - Properties
  private var conversations = [Conversation]()

  //MARK: - Subview's
  private let spinner = JGProgressHUD(style: .dark)

  private let tableView: UITableView = {
    let table = UITableView()
    table.isHidden = true
    table.register(ConversationTableViewCell.self, forCellReuseIdentifier: ConversationTableViewCell.identifier)
    return table
  }()

  private let noConversationsLabel: UILabel = {
    let label = UILabel()
    label.text = "No conversations!"
    label.textAlignment = .center
    label.textColor = .gray
    label.font = .systemFont(ofSize: 21, weight: .medium)
    label.isHidden = true
    return label
  }()

  //MARK: - View Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose,
                                                        target: self,
                                                        action: #selector(didTapComposeButton))
    view.addSubview(tableView)
    view.addSubview(noConversationsLabel)
    setupTableView()
    fetchConversations()
    startListeningForConversations()
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    validateAuth()
  }

  //MARK: - Layout
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    tableView.frame = view.bounds
  }

  //MARK: - Methods
  private func startListeningForConversations() {
    guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return }
    print("Starting conversation fetch...")
    let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
    DatabaseManager.shared.getAllConversations(for: safeEmail) { [weak self] result in
      switch result {
      case .success(let conversations):
        print("Successfully got conversatin model!")
        guard !conversations.isEmpty else { return }
        self?.conversations = conversations
        DispatchQueue.main.async {
          self?.tableView.reloadData()
        }
      case .failure(let error):
        print("Failed to get conversations - \(error)")
      }
    }
  }

  private func validateAuth() {
    if FirebaseAuth.Auth.auth().currentUser == nil {
      let vc = LoginViewController()
      let nav = UINavigationController(rootViewController: vc)
      nav.modalPresentationStyle = .fullScreen
      present(nav, animated: false)
    }
  }

  private func setupTableView() {
    tableView.delegate = self
    tableView.dataSource = self
  }

  private func fetchConversations() {
    tableView.isHidden = false
  }

  private func createNewConversation(result: [String: String]) {
    guard let name = result["name"], let email = result["email"] else { return }
    let vc = ChatViewController(with: email, id: nil)
    vc.isNewConversation = true
    vc.title = name
    vc.navigationItem.largeTitleDisplayMode = .never
    navigationController?.pushViewController(vc, animated: true)
  }

  //MARK: - Actions
  @objc private func didTapComposeButton() {
    let vc = NewConversationViewController()
    vc.completion = { [weak self] result in
      self?.createNewConversation(result: result)
    }
    let navVC = UINavigationController(rootViewController: vc)
    present(navVC, animated: true)
  }
}

//MARK: - UITableView Delegate & DataSource Protocols
extension ConversationsViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return conversations.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let model = conversations[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: ConversationTableViewCell.identifier, for: indexPath) as! ConversationTableViewCell
    cell.configure(with: model)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    let model = conversations[indexPath.row]
    let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
    vc.title = model.name
    vc.navigationItem.largeTitleDisplayMode = .never
    navigationController?.pushViewController(vc, animated: true)
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 120
  }
}
