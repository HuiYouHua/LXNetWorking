// LXAFNetworkActivityIndicatorManager.m
// Copyright (c) 2011–2016 Alamofire Software Foundation ( http://alamofire.org/ )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "LXAFNetworkActivityIndicatorManager.h"

#if TARGET_OS_IOS
#import "LXAFURLSessionManager.h"

typedef NS_ENUM(NSInteger, LXAFNetworkActivityManagerState) {
    LXAFNetworkActivityManagerStateNotActive,
    LXAFNetworkActivityManagerStateDelayingStart,
    LXAFNetworkActivityManagerStateActive,
    LXAFNetworkActivityManagerStateDelayingEnd
};

static NSTimeInterval const kDefaultLXAFNetworkActivityManagerActivationDelay = 1.0;
static NSTimeInterval const kDefaultLXAFNetworkActivityManagerCompletionDelay = 0.17;

static NSURLRequest * LXAFNetworkRequestFromNotification(NSNotification *notification) {
    if ([[notification object] respondsToSelector:@selector(originalRequest)]) {
        return [(NSURLSessionTask *)[notification object] originalRequest];
    } else {
        return nil;
    }
}

typedef void (^LXAFNetworkActivityActionBlock)(BOOL networkActivityIndicatorVisible);

@interface LXAFNetworkActivityIndicatorManager ()
@property (readwrite, nonatomic, assign) NSInteger activityCount;
@property (readwrite, nonatomic, strong) NSTimer *activationDelayTimer;
@property (readwrite, nonatomic, strong) NSTimer *completionDelayTimer;
@property (readonly, nonatomic, getter = isNetworkActivityOccurring) BOOL networkActivityOccurring;
@property (nonatomic, copy) LXAFNetworkActivityActionBlock networkActivityActionBlock;
@property (nonatomic, assign) LXAFNetworkActivityManagerState currentState;
@property (nonatomic, assign, getter=isNetworkActivityIndicatorVisible) BOOL networkActivityIndicatorVisible;

- (void)updateCurrentStateForNetworkActivityChange;
@end

@implementation LXAFNetworkActivityIndicatorManager

+ (instancetype)sharedManager {
    static LXAFNetworkActivityIndicatorManager *_sharedManager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedManager = [[self alloc] init];
    });

    return _sharedManager;
}

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    self.currentState = LXAFNetworkActivityManagerStateNotActive;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkRequestDidStart:) name:LXAFNetworkingTaskDidResumeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkRequestDidFinish:) name:LXAFNetworkingTaskDidSuspendNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkRequestDidFinish:) name:LXAFNetworkingTaskDidCompleteNotification object:nil];
    self.activationDelay = kDefaultLXAFNetworkActivityManagerActivationDelay;
    self.completionDelay = kDefaultLXAFNetworkActivityManagerCompletionDelay;

    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_activationDelayTimer invalidate];
    [_completionDelayTimer invalidate];
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    if (enabled == NO) {
        [self setCurrentState:LXAFNetworkActivityManagerStateNotActive];
    }
}

- (void)setNetworkingActivityActionWithBlock:(void (^)(BOOL networkActivityIndicatorVisible))block {
    self.networkActivityActionBlock = block;
}

- (BOOL)isNetworkActivityOccurring {
    @synchronized(self) {
        return self.activityCount > 0;
    }
}

- (void)setNetworkActivityIndicatorVisible:(BOOL)networkActivityIndicatorVisible {
    if (_networkActivityIndicatorVisible != networkActivityIndicatorVisible) {
        [self willChangeValueForKey:@"networkActivityIndicatorVisible"];
        @synchronized(self) {
             _networkActivityIndicatorVisible = networkActivityIndicatorVisible;
        }
        [self didChangeValueForKey:@"networkActivityIndicatorVisible"];
        if (self.networkActivityActionBlock) {
            self.networkActivityActionBlock(networkActivityIndicatorVisible);
        } else {
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:networkActivityIndicatorVisible];
        }
    }
}

- (void)setActivityCount:(NSInteger)activityCount {
	@synchronized(self) {
		_activityCount = activityCount;
	}

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCurrentStateForNetworkActivityChange];
    });
}

- (void)incrementActivityCount {
    [self willChangeValueForKey:@"activityCount"];
	@synchronized(self) {
		_activityCount++;
	}
    [self didChangeValueForKey:@"activityCount"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCurrentStateForNetworkActivityChange];
    });
}

- (void)decrementActivityCount {
    [self willChangeValueForKey:@"activityCount"];
	@synchronized(self) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
		_activityCount = MAX(_activityCount - 1, 0);
#pragma clang diagnostic pop
	}
    [self didChangeValueForKey:@"activityCount"];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateCurrentStateForNetworkActivityChange];
    });
}

- (void)networkRequestDidStart:(NSNotification *)notification {
    if ([LXAFNetworkRequestFromNotification(notification) URL]) {
        [self incrementActivityCount];
    }
}

- (void)networkRequestDidFinish:(NSNotification *)notification {
    if ([LXAFNetworkRequestFromNotification(notification) URL]) {
        [self decrementActivityCount];
    }
}

#pragma mark - Internal State Management
- (void)setCurrentState:(LXAFNetworkActivityManagerState)currentState {
    @synchronized(self) {
        if (_currentState != currentState) {
            [self willChangeValueForKey:@"currentState"];
            _currentState = currentState;
            switch (currentState) {
                case LXAFNetworkActivityManagerStateNotActive:
                    [self cancelActivationDelayTimer];
                    [self cancelCompletionDelayTimer];
                    [self setNetworkActivityIndicatorVisible:NO];
                    break;
                case LXAFNetworkActivityManagerStateDelayingStart:
                    [self startActivationDelayTimer];
                    break;
                case LXAFNetworkActivityManagerStateActive:
                    [self cancelCompletionDelayTimer];
                    [self setNetworkActivityIndicatorVisible:YES];
                    break;
                case LXAFNetworkActivityManagerStateDelayingEnd:
                    [self startCompletionDelayTimer];
                    break;
            }
        }
        [self didChangeValueForKey:@"currentState"];
    }
}

- (void)updateCurrentStateForNetworkActivityChange {
    if (self.enabled) {
        switch (self.currentState) {
            case LXAFNetworkActivityManagerStateNotActive:
                if (self.isNetworkActivityOccurring) {
                    [self setCurrentState:LXAFNetworkActivityManagerStateDelayingStart];
                }
                break;
            case LXAFNetworkActivityManagerStateDelayingStart:
                //No op. Let the delay timer finish out.
                break;
            case LXAFNetworkActivityManagerStateActive:
                if (!self.isNetworkActivityOccurring) {
                    [self setCurrentState:LXAFNetworkActivityManagerStateDelayingEnd];
                }
                break;
            case LXAFNetworkActivityManagerStateDelayingEnd:
                if (self.isNetworkActivityOccurring) {
                    [self setCurrentState:LXAFNetworkActivityManagerStateActive];
                }
                break;
        }
    }
}

- (void)startActivationDelayTimer {
    self.activationDelayTimer = [NSTimer
                                 timerWithTimeInterval:self.activationDelay target:self selector:@selector(activationDelayTimerFired) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.activationDelayTimer forMode:NSRunLoopCommonModes];
}

- (void)activationDelayTimerFired {
    if (self.networkActivityOccurring) {
        [self setCurrentState:LXAFNetworkActivityManagerStateActive];
    } else {
        [self setCurrentState:LXAFNetworkActivityManagerStateNotActive];
    }
}

- (void)startCompletionDelayTimer {
    [self.completionDelayTimer invalidate];
    self.completionDelayTimer = [NSTimer timerWithTimeInterval:self.completionDelay target:self selector:@selector(completionDelayTimerFired) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.completionDelayTimer forMode:NSRunLoopCommonModes];
}

- (void)completionDelayTimerFired {
    [self setCurrentState:LXAFNetworkActivityManagerStateNotActive];
}

- (void)cancelActivationDelayTimer {
    [self.activationDelayTimer invalidate];
}

- (void)cancelCompletionDelayTimer {
    [self.completionDelayTimer invalidate];
}

@end

#endif
