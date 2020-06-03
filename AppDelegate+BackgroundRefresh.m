//
//  AppDelegate+BackgroundRefresh.m
//  Elytra
//
//  Created by Nikhil Nigade on 04/05/20.
//  See LICENSE.md for License 
//

#import "AppDelegate+BackgroundRefresh.h"

#define backgroundRefreshIdentifier @"com.domain.app"

@implementation AppDelegate (BackgroundRefresh)

/// We create a unique background serial queue to 
/// dispatch all our task scheduling and processing on 
- (dispatch_queue_t)bgTaskDispatchQueue {
    
    if (_bgTaskDispatchQueue == nil) {
        _bgTaskDispatchQueue = dispatch_queue_create("BGTaskScheduler", DISPATCH_QUEUE_SERIAL);
    }
    
    return _bgTaskDispatchQueue;
    
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    
    /// We first cancle any pending tasks that we have already scheduled. 
    /// You can also optionally check if a task is scheduled and exit early
    /// from this method. 
    [BGTaskScheduler.sharedScheduler getPendingTaskRequestsWithCompletionHandler:^(NSArray<BGTaskRequest *> * _Nonnull taskRequests) {
        
        BOOL cancelling = NO;
        
        if (taskRequests != nil && taskRequests.count > 0) {
            
            [BGTaskScheduler.sharedScheduler cancelAllTaskRequests];
            
            cancelling = YES;
            
        }
        
        [self scheduleBackgroundRefresh];
        
        if (cancelling == YES) {
            
            /// Apple's suggested llvm snippet does not work. So we 
            /// trigger the background refresh from our code for 
            /// testing purposes. You should comment this bit out
            /// when not actively testing background refresh. 
            /// This also does not work on Simulators. 
            
#ifdef DEBUG
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

            dispatch_async(self.bgTaskDispatchQueue, ^{
                [[BGTaskScheduler sharedScheduler] performSelector:NSSelectorFromString(@"_simulateLaunchForTaskWithIdentifier:") withObject:backgroundRefreshIdentifier];
            });

#pragma clang diagnostic pop
#endif
            
        }
        
    }];
    
}

- (void)application:(UIApplication *)application handleEventsForBackgroundURLSession:(nonnull NSString *)identifier completionHandler:(nonnull void (^)(void))completionHandler {
    
#ifdef DEBUG
    NSLog(@"Got a fresh background completion handler");
#endif
    
    /// Send this to your Network Manager so it can call it 
    /// once it is ready to invalidate itself after completing
    /// all scheduled NSURLSessionTasks. 
    NetworkHandler.sharedInstance.backgroundCompletionHandler = completionHandler;
    
}

- (void)scheduleBackgroundRefresh {
    
    /// Doing this from one of our app's own queues causes a race condition 
    /// and can indefinitely hang the app. So we use our own serial queue here. 
    dispatch_async(self.bgTaskDispatchQueue, ^{
        
        BGAppRefreshTaskRequest *request = [[BGAppRefreshTaskRequest alloc] initWithIdentifier:backgroundRefreshIdentifier];

            // 1 hour from backgrounding. Adjust the values to suit your requirements. 
#ifdef DEBUG
            request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:1];
#else
            request.earliestBeginDate = [NSDate dateWithTimeIntervalSinceNow:(60 * 60)];
#endif

        NSError *error = nil;

        BOOL done = [[BGTaskScheduler sharedScheduler] submitTaskRequest:request error:&error];

        if (done == NO) {

            if (error != nil && error.code != 1) {

                NSLog(@"Error submitting bg refresh request: %@", error.localizedDescription);

            }

        }
        
    });
    
}

- (void)setupBackgroundRefresh {
    
    __weak typeof(self) weakSelf = self;
    
    BOOL registered = [[BGTaskScheduler sharedScheduler] registerForTaskWithIdentifier:backgroundRefreshIdentifier usingQueue:nil launchHandler:^(__kindof BGAppRefreshTask * _Nonnull task) {
        
        NSLog(@"Woken to perform background refresh.");
        
        typeof(weakSelf) strongSelf = self; 
        
        // schedule next refresh
        [strongSelf scheduleBackgroundRefresh];
        
        /// Remember to set the expiration handler and call 
        /// -[BGTask setTaskCompletedWithSuccess:] once you're 
        /// done processing. Your expiration handler may get called
        /// by the OS before you're done refreshing, so close immediately. 
        [AccountManager.sharedInstance handleBackgroundRefresh:task];

    }];
    
#ifdef DEBUG    
    NSLog(@"Registered background refresh task: %@", @(registered));
#endif     
    
}

