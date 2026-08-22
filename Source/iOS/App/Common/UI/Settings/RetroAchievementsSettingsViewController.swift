// Copyright 2026 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

import UIKit

final class RetroAchievementsSettingsViewController: UITableViewController {
  private let manager = DOLRetroAchievementsManager.shared
  private var username = ""
  private var password = ""
  private var signingIn = false

  override func viewDidLoad() {
    super.viewDidLoad()
    title = "RetroAchievements"
    username = manager.username
    tableView.keyboardDismissMode = .onDrag
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(retroAchievementsDidChange),
      name: Notification.Name("DOLRetroAchievementsDidChangeNotification"),
      object: manager
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  override func numberOfSections(in tableView: UITableView) -> Int {
    2
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      return 2
    }
    if !manager.isIntegrationEnabled {
      return 0
    }
    if manager.isLoggedIn {
      return 2
    }
    return manager.statusMessage == nil ? 3 : 4
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    section == 0 ? "Integration" : "Account"
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    guard section == 1 else { return nil }
    if !manager.isIntegrationEnabled {
      return "Enable RetroAchievements to sign in."
    }
    return "Passwords are used only to sign in and are not saved. Achievement unlocks appear through Dolphin's on-screen notifications."
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    if indexPath.section == 0 {
      if indexPath.row == 0 {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Enable RetroAchievements"
        let toggle = UISwitch()
        toggle.isOn = manager.isIntegrationEnabled
        toggle.addTarget(self, action: #selector(integrationSwitchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle
        cell.selectionStyle = .none
        return cell
      }

      let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
      cell.textLabel?.text = "Mode"
      cell.detailTextLabel?.text = "Softcore"
      cell.selectionStyle = .none
      return cell
    }

    if manager.isLoggedIn {
      if indexPath.row == 0 {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.text = manager.playerDisplayName
        cell.detailTextLabel?.text = "\(manager.playerScore) points"
        cell.selectionStyle = .none
        return cell
      }
      return actionCell(title: "Log Out", color: .systemRed)
    }

    if indexPath.row == 0 {
      return textFieldCell(
        placeholder: "Username",
        text: username,
        secure: false,
        selector: #selector(usernameChanged(_:))
      )
    }
    if indexPath.row == 1 {
      return textFieldCell(
        placeholder: "Password",
        text: password,
        secure: true,
        selector: #selector(passwordChanged(_:))
      )
    }
    if indexPath.row == 2 {
      let cell = actionCell(title: signingIn ? "Signing In…" : "Log In", color: .systemBlue)
      cell.isUserInteractionEnabled = !signingIn
      return cell
    }

    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.textLabel?.text = manager.statusMessage
    cell.textLabel?.textColor = .systemRed
    cell.textLabel?.numberOfLines = 0
    cell.selectionStyle = .none
    return cell
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    guard indexPath.section == 1 else { return }

    if manager.isLoggedIn && indexPath.row == 1 {
      manager.logout()
      password = ""
      return
    }

    if !manager.isLoggedIn && indexPath.row == 2 && !signingIn {
      view.endEditing(true)
      signingIn = true
      tableView.reloadData()
      manager.login(withUsername: username, password: password) { [weak self] success, _ in
        guard let self else { return }
        self.signingIn = false
        if success {
          self.password = ""
        }
        self.tableView.reloadData()
      }
    }
  }

  private func textFieldCell(
    placeholder: String,
    text: String,
    secure: Bool,
    selector: Selector
  ) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    let textField = UITextField()
    textField.translatesAutoresizingMaskIntoConstraints = false
    textField.placeholder = placeholder
    textField.text = text
    textField.isSecureTextEntry = secure
    textField.autocapitalizationType = .none
    textField.autocorrectionType = .no
    textField.textContentType = secure ? .password : .username
    textField.returnKeyType = secure ? .done : .next
    textField.addTarget(self, action: selector, for: .editingChanged)
    cell.contentView.addSubview(textField)
    NSLayoutConstraint.activate([
      textField.leadingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.leadingAnchor),
      textField.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
      textField.topAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.topAnchor),
      textField.bottomAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.bottomAnchor)
    ])
    cell.selectionStyle = .none
    return cell
  }

  private func actionCell(title: String, color: UIColor) -> UITableViewCell {
    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
    cell.textLabel?.text = title
    cell.textLabel?.textAlignment = .center
    cell.textLabel?.textColor = color
    return cell
  }

  @objc private func integrationSwitchChanged(_ sender: UISwitch) {
    manager.setIntegrationEnabled(sender.isOn)
    tableView.reloadData()
  }

  @objc private func usernameChanged(_ sender: UITextField) {
    username = sender.text ?? ""
  }

  @objc private func passwordChanged(_ sender: UITextField) {
    password = sender.text ?? ""
  }

  @objc private func retroAchievementsDidChange() {
    tableView.reloadData()
  }
}
