// Copyright 2026 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#import "RetroAchievementsManager.h"

#include <string>

#include "Common/Config/Config.h"
#include "Core/AchievementManager.h"
#include "Core/Config/AchievementSettings.h"

NSNotificationName const DOLRetroAchievementsDidChangeNotification =
    @"DOLRetroAchievementsDidChangeNotification";

@interface DOLRetroAchievementsManager ()

@property(nonatomic, readwrite, getter=isLoggedIn) BOOL loggedIn;
@property(nonatomic, readwrite) NSString* playerDisplayName;
@property(nonatomic, readwrite) NSUInteger playerScore;
@property(nonatomic, readwrite, nullable) NSString* statusMessage;
@property(nonatomic, copy, nullable) DOLRetroAchievementsLoginCompletion loginCompletion;

@end

@implementation DOLRetroAchievementsManager

+ (DOLRetroAchievementsManager*)shared
{
  static DOLRetroAchievementsManager* manager;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manager = [[DOLRetroAchievementsManager alloc] init];
  });
  return manager;
}

- (instancetype)init
{
  self = [super init];
  if (self)
    _playerDisplayName = @"";
  return self;
}

- (BOOL)isIntegrationEnabled
{
  return Config::Get(Config::RA_ENABLED);
}

- (NSString*)username
{
  const std::string username = Config::Get(Config::RA_USERNAME);
  return [NSString stringWithUTF8String:username.c_str()];
}

- (void)start
{
  Config::SetBaseOrCurrent(Config::RA_HARDCORE_ENABLED, false);
  if (!self.integrationEnabled)
    return;

  AchievementManager& manager = AchievementManager::GetInstance();
  [self installUpdateCallback:manager];
  self.statusMessage = manager.HasAPIToken() ? @"Signing in…" : nil;
  manager.Init(nullptr);
}

- (void)shutdown
{
  AchievementManager::GetInstance().Shutdown();
}

- (void)setBackgroundExecutionAllowed:(BOOL)allowed
{
  if (self.integrationEnabled)
    AchievementManager::GetInstance().SetBackgroundExecutionAllowed(allowed);
}

- (void)setIntegrationEnabled:(BOOL)enabled
{
  if (enabled == self.integrationEnabled)
    return;

  Config::SetBaseOrCurrent(Config::RA_HARDCORE_ENABLED, false);
  Config::SetBaseOrCurrent(Config::RA_ENABLED, enabled);

  AchievementManager& manager = AchievementManager::GetInstance();
  if (enabled)
  {
    [self installUpdateCallback:manager];
    self.statusMessage = manager.HasAPIToken() ? @"Signing in…" : nil;
    manager.Init(nullptr);
  }
  else
  {
    manager.Shutdown();
    if (self.loginCompletion)
    {
      self.loginCompletion(NO, @"Sign-in cancelled.");
      self.loginCompletion = nil;
    }
    self.loggedIn = NO;
    self.playerDisplayName = @"";
    self.playerScore = 0;
    self.statusMessage = nil;
  }

  Config::Save();
  [self postChangeNotification];
}

- (void)loginWithUsername:(NSString*)username
                 password:(NSString*)password
               completion:(DOLRetroAchievementsLoginCompletion)completion
{
  NSString* trimmedUsername =
      [username stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (trimmedUsername.length == 0 || password.length == 0)
  {
    completion(NO, @"Enter both your RetroAchievements username and password.");
    return;
  }

  if (!self.integrationEnabled)
    [self setIntegrationEnabled:YES];

  AchievementManager& manager = AchievementManager::GetInstance();
  if (manager.HasAPIToken())
    manager.Logout();

  Config::SetBaseOrCurrent(Config::RA_HARDCORE_ENABLED, false);
  Config::SetBaseOrCurrent(Config::RA_USERNAME, trimmedUsername.UTF8String);
  self.loginCompletion = completion;
  self.statusMessage = @"Signing in…";
  [self postChangeNotification];
  manager.Login(password.UTF8String);
}

- (void)logout
{
  if (self.integrationEnabled)
    AchievementManager::GetInstance().Logout();
  else
    Config::SetBaseOrCurrent(Config::RA_API_TOKEN, "");

  Config::Save();
  self.loggedIn = NO;
  self.playerDisplayName = @"";
  self.playerScore = 0;
  self.statusMessage = nil;
  self.loginCompletion = nil;
  [self postChangeNotification];
}

- (void)installUpdateCallback:(AchievementManager&)manager
{
  manager.SetUpdateCallback([self, &manager](const AchievementManager::UpdatedItems& update) {
    NSString* errorMessage = nil;
    if (update.failed_login_code != 0)
      errorMessage = [NSString stringWithUTF8String:rc_error_str(update.failed_login_code)];

    std::string displayName;
    NSUInteger score = 0;
    if (manager.GetClient())
    {
      std::lock_guard lock(manager.GetLock());
      displayName = manager.GetPlayerDisplayName();
      score = manager.GetPlayerScore();
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (!self.integrationEnabled)
      {
        self.loggedIn = NO;
        self.playerDisplayName = @"";
        self.playerScore = 0;
      }
      else if (errorMessage)
      {
        self.loggedIn = NO;
        self.playerDisplayName = @"";
        self.playerScore = 0;
        self.statusMessage = errorMessage;
        if (self.loginCompletion)
        {
          self.loginCompletion(NO, errorMessage);
          self.loginCompletion = nil;
        }
      }
      else if (!displayName.empty())
      {
        self.loggedIn = YES;
        self.playerDisplayName = [NSString stringWithUTF8String:displayName.c_str()];
        self.playerScore = score;
        self.statusMessage = nil;
        if (self.loginCompletion)
        {
          self.loginCompletion(YES, nil);
          self.loginCompletion = nil;
        }
        Config::Save();
      }

      [self postChangeNotification];
    });
  });
}

- (void)postChangeNotification
{
  [NSNotificationCenter.defaultCenter postNotificationName:DOLRetroAchievementsDidChangeNotification
                                                    object:self];
}

@end
