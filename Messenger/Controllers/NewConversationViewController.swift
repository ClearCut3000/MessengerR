//
//  NewConversationViewController.swift
//  Messenger
//
//  Created by Николай Никитин on 28.04.2022.
//

import UIKit
import JGProgressHUD

final class NewConversationViewController: UIViewController {

  //MARK: - Properties
  private var users = [[String: String]]()
  private var hasFetched = false
  private var results = [SearchResult]()
  public var completion: ((SearchResult) -> (Void))?

  //MARK: - Subview's
  private let spinner = JGProgressHUD(style: .dark)

  private let searchBar: UISearchBar = {
    let searchBar = UISearchBar()
    searchBar.placeholder = "Search for users..."
    return searchBar
  }()

  private let tableView: UITableView = {
    let table = UITableView()
    table.isHidden = true
    table.register(NewConversationCell.self, forCellReuseIdentifier: NewConversationCell.identifier)
    return table
  }()

  private let noResultsLabel: UILabel = {
    let label = UILabel()
    label.isHidden = true
    label.text = "No Results"
    label.textAlignment = .center
    label.textColor = .green
    label.font = .systemFont(ofSize: 21, weight: .medium)
    return label
  }()

  //MARK: - View Lifecycle
  override func viewDidLoad() {
    super.viewDidLoad()
    view.addSubview(noResultsLabel)
    view.addSubview(tableView)

    tableView.delegate = self
    tableView.dataSource = self

    searchBar.delegate = self

    view.backgroundColor = .systemBackground
    navigationController?.navigationBar.topItem?.titleView = searchBar
    navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel",
                                                        style: .done,
                                                        target: self,
                                                        action: #selector(dismissSelf))
    searchBar.becomeFirstResponder()
  }

  //MARK: - Layout
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    tableView.frame = view.bounds
    noResultsLabel.frame = CGRect(x: view.width/4,
                                  y: (view.height - 200)/2,
                                  width: view.width/2,
                                  height: 200)
  }

  //MARK: - Action's
  @objc private func dismissSelf() {
    dismiss(animated: true, completion: nil)
  }
}

//MARK: - UITableView Delegate & DataSource
extension NewConversationViewController: UITableViewDelegate, UITableViewDataSource {
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return results.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let model = results[indexPath.row]
    let cell = tableView.dequeueReusableCell(withIdentifier: NewConversationCell.identifier, for: indexPath) as! NewConversationCell
    cell.configure(with: model)
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    //start conversation
    let targetUserData = results[indexPath.row]
    dismiss(animated: true) { [weak self] in
      self?.completion?(targetUserData)
    }
  }

  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 90
  }
}

//MARK: - UISearchBarDelegate & Search Method's
extension NewConversationViewController: UISearchBarDelegate {
  func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
    guard let text = searchBar.text, !text.replacingOccurrences(of: " ", with: "").isEmpty else { return }
    searchBar.resignFirstResponder()
    results.removeAll()
    spinner.show(in: view)
    searchUsers(query: text)
  }

  func searchUsers(query: String) {
    //check if array has firebase results
    if hasFetched {
      //if it does: filter
      filterUsers(with: query)
    } else {
      //if it not, fetch then filter
      DatabaseManager.shared.getAllUsers { [weak self] result in
        switch result {
        case .success(let usersCollection):
          self?.hasFetched = true
          self?.users = usersCollection
          self?.filterUsers(with: query)
        case .failure(let error):
          print("Failed to get users - \(error)")
        }
      }
    }
  }

  func filterUsers(with term: String) {
    //update UI: either show results or show no results label
    guard let currentUserEmail = UserDefaults.standard.value(forKey: "email") as? String, hasFetched else { return }
    let safeEmail = DatabaseManager.safeEmail(emailAddress: currentUserEmail)
    self.spinner.dismiss()
    let results: [SearchResult] = users.filter {
      guard let email = $0["email"],
            email != safeEmail else { return false }
      guard let name = $0["name"]?.lowercased() else { return false }
      return name.hasPrefix(term.lowercased())
    }.compactMap {
      guard let name = $0["name"], let email = $0["email"] else { return nil }
      return SearchResult(name: name, email: email)
    }
    self.results = results
    updateUI()
  }

  func updateUI() {
    if results.isEmpty {
      noResultsLabel.isHidden = false
      tableView.isHidden = true
    } else {
      noResultsLabel.isHidden = true
      tableView.isHidden = false
      tableView.reloadData()
    }
  }
}
