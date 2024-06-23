#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.ichitaso.iconorder.plist"
#define KEY @"IconOrder"
#define ANCHOR_KEY @"AnchorPositions"

@interface SBHHomeScreenIconGridLayoutConfiguration : NSObject
@property(nonatomic) NSUInteger numberOfPortraitRows;
@property(nonatomic) NSUInteger numberOfPortraitColumns;
@end

@interface SBHIconGridConfiguration : NSObject
@property (nonatomic, readonly) SBHHomeScreenIconGridLayoutConfiguration *homeScreenConfiguration;
@end

@interface SBIconView : UIView
@property (nonatomic, retain) NSString *applicationBundleIdentifierForShortcuts;
- (void)setLocation:(CGPoint)location;
- (CGPoint)location;
@end

@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
- (SBHIconGridConfiguration *)iconGridConfiguration;
- (NSArray *)visibleIconViewsInRootFolder;
@end

static NSMutableDictionary *anchorPositions;
static NSMutableDictionary *mutableDict;

%hook SBIconView

- (void)setLocation:(CGPoint)location {
    @try {
        NSString *bundleID = self.applicationBundleIdentifierForShortcuts;
        if (bundleID && anchorPositions) {
            NSValue *anchoredLocationValue = anchorPositions[bundleID];
            if (anchoredLocationValue) {
                CGPoint anchoredLocation = [anchoredLocationValue CGPointValue];
                if (!CGPointEqualToPoint(anchoredLocation, CGPointZero)) {
                    location = anchoredLocation;
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in setLocation: %@", exception);
    }
    %orig(location);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig;
    @try {
        UITouch *touch = [touches anyObject];
        if (touch) {
            CGPoint location = [touch locationInView:self.superview];
            NSString *bundleID = self.applicationBundleIdentifierForShortcuts;
            if (bundleID && anchorPositions) {
                anchorPositions[bundleID] = [NSValue valueWithCGPoint:location];
                [self setLocation:location];
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in touchesMoved: %@", exception);
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig;
    @try {
        if (mutableDict && anchorPositions) {
            mutableDict[ANCHOR_KEY] = anchorPositions;
            [mutableDict writeToFile:PREF_PATH atomically:YES];
        }
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in touchesEnded: %@", exception);
    }
}

%end

%hook SBHHomeScreenIconGridLayoutConfiguration
- (NSUInteger)maximumIconCount {
    NSUInteger originalCount = %orig;
    NSUInteger customCount = self.numberOfPortraitRows * self.numberOfPortraitColumns;
    return MAX(originalCount, customCount);
}
%end

%hook SBIconController
- (id)iconState {
    id orig = %orig;
    @try {
        if (mutableDict) {
            id storedState = mutableDict[KEY];
            if (storedState) {
                return storedState;
            }
            mutableDict[KEY] = orig;
            [mutableDict writeToFile:PREF_PATH atomically:YES];
        }
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in iconState: %@", exception);
    }
    return orig;
}

- (void)setIconState:(id)state {
    @try {
        if (mutableDict) {
            mutableDict[KEY] = state;
            [mutableDict writeToFile:PREF_PATH atomically:YES];
        }
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in setIconState: %@", exception);
    }
    %orig(state);
}
%end

%ctor {
    @try {
        anchorPositions = [NSMutableDictionary dictionary];
        NSDictionary *savedDict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
        mutableDict = savedDict ? [savedDict mutableCopy] : [NSMutableDictionary dictionary];
        
        NSDictionary *savedAnchorPositions = mutableDict[ANCHOR_KEY];
        if (savedAnchorPositions) {
            [anchorPositions addEntriesFromDictionary:savedAnchorPositions];
        }
        
        %init;
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in ctor: %@", exception);
    }
}
