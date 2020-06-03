//
//  AppDelegate+BackgroundRefresh.h
//  Elytra
//
//  Created by Nikhil Nigade on 04/05/20.
//  See LICENSE.md for LICENSE 
//

#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@interface AppDelegate (BackgroundRefresh)

- (void)applicationDidEnterBackground:(UIApplication *)application;

- (void)setupBackgroundRefresh;

@end

NS_ASSUME_NONNULL_END
