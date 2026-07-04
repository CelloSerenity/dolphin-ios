// Copyright 2026 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "ControllersDSUClientViewController.h"

#import <limits>

#import <fmt/format.h>

#import "Common/Config/Config.h"
#import "Common/StringUtil.h"
#import "InputCommon/ControllerInterface/DualShockUDPClient/DualShockUDPClient.h"

namespace
{
struct DSUServerEntry
{
  std::string description;
  std::string address;
  u16 port;
};

std::vector<DSUServerEntry> GetServers()
{
  std::vector<DSUServerEntry> servers;

  const auto servers_setting = Config::Get(ciface::DualShockUDPClient::Settings::SERVERS);
  const auto server_details = SplitString(servers_setting, ';');
  for (const auto& server_detail : server_details)
  {
    const auto server_info = SplitString(server_detail, ':');
    if (server_info.size() < 3)
      continue;

    const int port = std::atoi(server_info[2].c_str());
    if (port <= 0 || port >= std::numeric_limits<u16>::max())
      continue;

    servers.push_back({server_info[0], server_info[1], static_cast<u16>(port)});
  }

  return servers;
}

void SetServers(const std::vector<DSUServerEntry>& servers)
{
  std::string new_servers_setting;
  for (const auto& server : servers)
    new_servers_setting += fmt::format("{}:{}:{};", server.description, server.address, server.port);

  Config::SetBaseOrCurrent(ciface::DualShockUDPClient::Settings::SERVERS, new_servers_setting);
}
}  // namespace

static NSString* const kEnableCellId = @"DSUEnableCell";
static NSString* const kServerCellId = @"DSUServerCell";

@interface ControllersDSUClientViewController () <UITextFieldDelegate>

@property (nonatomic) UISwitch* enableSwitch;

@end

@implementation ControllersDSUClientViewController {
  std::vector<DSUServerEntry> _servers;
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.title = @"DSU Client";

  [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:kEnableCellId];

  self.navigationItem.rightBarButtonItem =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                     target:self
                                                     action:@selector(addServerTapped)];

  self.enableSwitch = [[UISwitch alloc] init];
  [self.enableSwitch addTarget:self
                         action:@selector(enableSwitchChanged:)
               forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  self.enableSwitch.on = Config::Get(ciface::DualShockUDPClient::Settings::SERVERS_ENABLED);
  _servers = GetServers();

  [self.tableView reloadData];
}

- (void)enableSwitchChanged:(UISwitch*)sender {
  Config::SetBaseOrCurrent(ciface::DualShockUDPClient::Settings::SERVERS_ENABLED, (bool)sender.on);
}

- (void)addServerTapped {
  UIAlertController* alert =
      [UIAlertController alertControllerWithTitle:@"Add DSU Server"
                                           message:@"Enter the details of the DSU server to connect to."
                                    preferredStyle:UIAlertControllerStyleAlert];

  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.placeholder = @"Description (e.g. BetterJoy)";
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.placeholder = @"Server IP Address";
    textField.text = @(ciface::DualShockUDPClient::DEFAULT_SERVER_ADDRESS);
    textField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
  }];
  [alert addTextFieldWithConfigurationHandler:^(UITextField* textField) {
    textField.placeholder = @"Server Port";
    textField.text = [NSString stringWithFormat:@"%d", ciface::DualShockUDPClient::DEFAULT_SERVER_PORT];
    textField.keyboardType = UIKeyboardTypeNumberPad;
  }];

  __weak UIAlertController* weakAlert = alert;
  [alert addAction:[UIAlertAction actionWithTitle:@"Add"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction* action) {
    [self onAddServerConfirmed:weakAlert];
  }]];
  [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];

  [self presentViewController:alert animated:YES completion:nil];
}

- (void)onAddServerConfirmed:(UIAlertController*)alert {
  NSString* description = alert.textFields[0].text;
  NSString* address = alert.textFields[1].text;
  NSString* portString = alert.textFields[2].text;

  const int port = portString.intValue;
  if (address.length == 0 || port <= 0 || port >= std::numeric_limits<u16>::max())
    return;

  DSUServerEntry entry;
  entry.description = description.length > 0 ? description.UTF8String : "DSU Server";
  entry.address = address.UTF8String;
  entry.port = static_cast<u16>(port);

  _servers.push_back(entry);
  SetServers(_servers);

  [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView*)tableView {
  return 2;
}

- (NSInteger)tableView:(UITableView*)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 0)
    return 1;

  return _servers.empty() ? 1 : static_cast<NSInteger>(_servers.size());
}

- (nullable NSString*)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
  return section == 1 ? @"Servers" : nil;
}

- (nullable NSString*)tableView:(UITableView*)tableView titleForFooterInSection:(NSInteger)section {
  if (section != 1)
    return nil;

  return @"DSU protocol enables the use of input and motion data from compatible sources, like "
         @"PlayStation, Nintendo Switch and Steam controllers.";
}

- (UITableViewCell*)tableView:(UITableView*)tableView cellForRowAtIndexPath:(NSIndexPath*)indexPath {
  if (indexPath.section == 0) {
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kEnableCellId forIndexPath:indexPath];
    cell.textLabel.text = @"Enable";
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = self.enableSwitch;
    return cell;
  }

  UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:kServerCellId];
  if (cell == nil) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                   reuseIdentifier:kServerCellId];
  }
  cell.selectionStyle = UITableViewCellSelectionStyleNone;

  if (_servers.empty()) {
    cell.textLabel.text = @"No servers configured";
    cell.textLabel.textColor = [UIColor secondaryLabelColor];
    cell.detailTextLabel.text = nil;
  } else {
    const auto& server = _servers[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%s:%d", server.address.c_str(), server.port];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.text = @(server.description.c_str());
  }

  return cell;
}

- (BOOL)tableView:(UITableView*)tableView canEditRowAtIndexPath:(NSIndexPath*)indexPath {
  return indexPath.section == 1 && !_servers.empty();
}

- (void)tableView:(UITableView*)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
     forRowAtIndexPath:(NSIndexPath*)indexPath {
  if (editingStyle != UITableViewCellEditingStyleDelete || indexPath.section != 1)
    return;

  _servers.erase(_servers.begin() + indexPath.row);
  SetServers(_servers);

  [tableView reloadData];
}

@end
