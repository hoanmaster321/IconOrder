#import <UIKit/UIKit.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.ichitaso.iconorder.plist"
#define KEY @"IconOrder"

@interface SBHHomeScreenIconGridLayoutConfiguration : NSObject
@property(nonatomic) NSUInteger numberOfPortraitRows;
@property(nonatomic) NSUInteger numberOfPortraitColumns;
@end

@interface SBHIconGridConfiguration : NSObject
@property (nonatomic, readonly) SBHHomeScreenIconGridLayoutConfiguration *homeScreenConfiguration;
@end

@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
- (SBHIconGridConfiguration *)iconGridConfiguration;
@end

static NSUInteger SBHHomeScreenIconGridLayoutConfiguration_maximumIconCount(SBHHomeScreenIconGridLayoutConfiguration* self, SEL _cmd) {
    return self.numberOfPortraitRows * self.numberOfPortraitColumns;
}

%hook SBHHomeScreenIconGridLayoutConfiguration
- (NSUInteger)maximumIconCount {
    return SBHHomeScreenIconGridLayoutConfiguration_maximumIconCount(self, _cmd);
}
%end

NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
NSMutableDictionary *mutableDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];

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
    class_addMethod(objc_getClass("SBIconListFlowExtendedLayout"), @selector(maximumIconCount), (IMP)&SBIconListFlowExtendedLayout_maximumIconCount, "Q@:");
    %init;
}
