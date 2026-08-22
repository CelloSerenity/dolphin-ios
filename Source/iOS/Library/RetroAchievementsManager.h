// Copyright 2026 DolphiniOS Project
// SPDX-License-Identifier: GPL-2.0-or-later

#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const DOLRetroAchievementsDidChangeNotification;

typedef void (^DOLRetroAchievementsLoginCompletion)(BOOL success, NSString* _Nullable errorMessage);

@interface DOLRetroAchievementsManager : NSObject

@property(class, nonatomic, readonly) DOLRetroAchievementsManager* shared;
@property(nonatomic, readonly, getter=isIntegrationEnabled) BOOL integrationEnabled;
@property(nonatomic, readonly, getter=isLoggedIn) BOOL loggedIn;
@property(nonatomic, readonly) NSString* username;
@property(nonatomic, readonly) NSString* playerDisplayName;
@property(nonatomic, readonly) NSUInteger playerScore;
@property(nonatomic, readonly, nullable) NSString* statusMessage;

- (void)start;
- (void)shutdown;
- (void)setBackgroundExecutionAllowed:(BOOL)allowed;
- (void)setIntegrationEnabled:(BOOL)enabled;
- (void)loginWithUsername:(NSString*)username
                 password:(NSString*)password
               completion:(DOLRetroAchievementsLoginCompletion)completion;
- (void)logout;

@end

NS_ASSUME_NONNULL_END
