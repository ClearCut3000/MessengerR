//
//  ConversationsViewController.swift
//  Messenger
//
//  Created by Николай Никитин on 28.04.2022.
//

import UIKit
import FirebaseAuth
import JGProgressHUD

/// Controller that shows list of conversations
final class ConversationsViewController: UIViewController {

  //MARK: - Properties
  private var conversations = [Conversation]()

  private var loginObserver: NSObjectProtocol?

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
    startListeningForConversations()

    loginObserver = NotificationCenter.default.addObserver(forName: .didLogInNotification,
                                                           object: nil,
                                                           queue: .main) { [weak self] _ in
      guard let strongSelf = self else { return }
      strongSelf.startListeningForConversations()
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    validateAuth()
  }

  //MARK: - Layout
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    tableView.frame = view.bounds
    noConversationsLabel.frame = CGRect(x: 10,
                                        y: (view.height - 100)/2,
                                        width: view.width - 20,
                                        height: 100)
  }

  //MARK: - Methods
  private func startListeningForConversations() {
    guard let email = UserDefaults.standard.value(forKey: "email") as? String else { return }

    if let observer = loginObserver {
      NotificationCenter.default.removeObserver(observer)
    }

    print("Starting conversation fetch...")
    let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
    DatabaseManager.shared.getAllConversations(for: safeEmail) { [weak self] result in
      switch result {
      case .success(let conversations):
        print("Successfully got conversatin model!")
        guard !conversations.isEmpty else {
          self?.tableView.isHidden = true
          self?.noConversationsLabel.isHidden = false
          return
        }
        self?.noConversationsLabel.isHidden = true
        self?.tableView.isHidden = false
        self?.conversations = conversations
        DispatchQueue.main.async {
          self?.tableView.reloadData()
        }
      case .failure(let error):
        self?.tableView.isHidden = true
        self?.noConversationsLabel.isHidden = false
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

  private func createNewConversation(result: SearchResult) {
    let name = result.name
    let email = DatabaseManager.safeEmail(emailAddress: result.email)
    //check in database if conversation with these two users exists
    //if it does, reuse conversation ID's
    //otherwise use existing code

    DatabaseManager.shared.conversationExists(with: email) { [weak self] result in
      guard let strongSelf = self else { return }
      switch result {
      case .success(let conversationID):
        let vc = ChatViewController(with: email, id: conversationID)
        vc.isNewConversation = false
        vc.title = name
        vc.navigationItem.largeTitleDisplayMode = .never
        strongSelf.navigationController?.pushViewController(vc, animated: true)
      case .failure(_):
        let vc = ChatViewController(with: email, id: nil)
        vc.isNewConversation = true
        vc.title = name
        vc.navigationItem.largeTitleDisplayMode = .never
        strongSelf.navigationController?.pushViewController(vc, animated: true)
      }
    }
  }

  //MARK: - Actions
  @objc private func didTapComposeButton() {
    let vc = NewConversationViewController()
    vc.completion = { [weak self] result in
      guard let strongSelf = self else { return }
      let currentConversations = strongSelf.conversations
      if let targetConversation = currentConversations.first(where: { $0.otherUserEmail == DatabaseManager.safeEmail(emailAddress: result.email)}) {
        let vc = ChatViewController(with: targetConversation.otherUserEmail, id: targetConversation.id)
        vc.isNewConversation = false
        vc.title = targetConversation.name
        vc.navigationItem.largeTitleDisplayMode = .never
        strongSelf.navigationController?.pushViewController(vc, animated: true)
      } else {
        strongSelf.createNewConversation(result: result)
      }
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
    openConversation(model)
  }

  func openConversation(_ model: Conversation) {
    let vc = ChatViewController(with: model.otherUserEmail, id: model.id)
    vc.title = model.name
    vc.navigationItem.largeTitleDisplayMode = .never
    navigationController?.pushViewController(vc, animated: true)
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 120
  }

  func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
    return .delete
  }

  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete {
      let conversationID = conversations[indexPath.row].id
      tableView.beginUpdates()
      DatabaseManager.shared.deleteConversation(conversationID: conversationID) { [weak self] success in
        if success {
          self?.conversations.remove(at: indexPath.row)
          tableView.deleteRows(at: [indexPath], with: .left)
        }
      }
      tableView.endUpdates()
    }
  }
}
