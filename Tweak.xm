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
    NSString *bundleID = self.applicationBundleIdentifierForShortcuts;
    if (bundleID) {
        CGPoint anchoredLocation = [[anchorPositions objectForKey:bundleID] CGPointValue];
        if (!CGPointEqualToPoint(anchoredLocation, CGPointZero)) {
            location = anchoredLocation;
        }
    }
    %orig(location);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig;
    UITouch *touch = [touches anyObject];
    CGPoint location = [touch locationInView:self.superview];
    NSString *bundleID = self.applicationBundleIdentifierForShortcuts;
    if (bundleID) {
        [anchorPositions setObject:[NSValue valueWithCGPoint:location] forKey:bundleID];
        [self setLocation:location];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig;
    [mutableDict setObject:anchorPositions forKey:ANCHOR_KEY];
    [mutableDict writeToFile:PREF_PATH atomically:YES];
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
    if ([mutableDict objectForKey:KEY]) {
        return [mutableDict objectForKey:KEY];
    }
    [mutableDict setValue:orig forKey:KEY];
    [mutableDict writeToFile:PREF_PATH atomically:YES];
    return orig;
}

- (void)setIconState:(id)state {
    [mutableDict setValue:state forKey:KEY];
    [mutableDict writeToFile:PREF_PATH atomically:YES];
    %orig(state);
}
%end

%ctor {
    anchorPositions = [NSMutableDictionary dictionary];
    NSDictionary *savedDict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    mutableDict = savedDict ? [savedDict mutableCopy] : [NSMutableDictionary dictionary];
    
    NSDictionary *savedAnchorPositions = [mutableDict objectForKey:ANCHOR_KEY];
    if (savedAnchorPositions) {
        [anchorPositions addEntriesFromDictionary:savedAnchorPositions];
    }
    
    %init;
}
