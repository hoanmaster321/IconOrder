#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define PREF_PATH @"/var/mobile/Library/Preferences/com.ichitaso.iconorder.plist"
#define KEY @"IconOrder"
#define ICON_POSITIONS_KEY @"IconPositions"

// Define classes/interfaces
@interface SBIconListGridLayoutConfiguration : NSObject
@property(nonatomic) NSUInteger numberOfPortraitRows;
@property(nonatomic) NSUInteger numberOfPortraitColumns;
@end

@interface SBIconListFlowExtendedLayout : NSObject
@property (nonatomic,copy,readonly) SBIconListGridLayoutConfiguration * layoutConfiguration;
@end

@interface SBIconView : UIView
@property (nonatomic, assign) CGPoint iconPosition;
@end

@interface SBIcon : NSObject
- (SBIconView *)iconView;
@end

@interface SBDefaultIconModelStore : NSObject
- (id)loadCurrentIconState:(id*)error;
- (BOOL)saveCurrentIconState:(id)state error:(id*)error;
@end

// Declare static function to calculate maximum icon count
static NSUInteger SBIconListFlowExtendedLayout_maximumIconCount(__unsafe_unretained SBIconListFlowExtendedLayout* const self, SEL _cmd) {
    return self.layoutConfiguration.numberOfPortraitRows * self.layoutConfiguration.numberOfPortraitColumns;
}

%hook SBIcon

- (void)setIconState:(id)state {
    @try {
        if ([state isKindOfClass:NSMutableDictionary.class]) {
            NSMutableDictionary *iconState = (NSMutableDictionary *)state;
            CGPoint position = [[self iconView] iconPosition];
            iconState[@"position"] = [NSValue valueWithCGPoint:position];
        }
        
        %orig;
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in setIconState: - %@", exception);
    }
}

%end

%hook SBDefaultIconModelStore

- (id)loadCurrentIconState:(id*)error {
    id orig = %orig;
    
    @try {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
        NSMutableDictionary *mutableDict = dict ? [dict mutableCopy] : [NSMutableDictionary dictionary];
        
        if ([mutableDict objectForKey:KEY]) {
            return [mutableDict objectForKey:KEY];
        }
        
        [mutableDict setValue:orig forKey:KEY];
        [mutableDict writeToFile:PREF_PATH atomically:YES];
        
        // Load icon positions if available
        NSMutableDictionary *iconPositions = mutableDict[ICON_POSITIONS_KEY];
        if (iconPositions && [orig respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
            [orig enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isKindOfClass:NSDictionary.class] && [obj[@"position"] isKindOfClass:NSValue.class]) {
                    iconPositions[key] = obj[@"position"];
                }
            }];
        }
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in loadCurrentIconState: - %@", exception);
    }
    
    return orig;
}

- (BOOL)saveCurrentIconState:(id)state error:(id*)error {
    @try {
        // Save icon positions
        if ([state respondsToSelector:@selector(enumerateKeysAndObjectsUsingBlock:)]) {
            NSMutableDictionary *iconPositions = [NSMutableDictionary dictionary];
            [state enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isKindOfClass:NSDictionary.class] && [obj[@"position"] isKindOfClass:NSValue.class]) {
                    iconPositions[key] = obj[@"position"];
                }
            }];
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH];
            if (!dict) {
                dict = [NSMutableDictionary dictionary];
            }
            dict[ICON_POSITIONS_KEY] = iconPositions;
            [dict writeToFile:PREF_PATH atomically:YES];
        }
        
        NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH];
        if (!mutableDict) {
            mutableDict = [NSMutableDictionary dictionary];
        }
        [mutableDict setValue:state forKey:KEY];
        [mutableDict writeToFile:PREF_PATH atomically:YES];
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in saveCurrentIconState: - %@", exception);
    }
    
    return %orig;
}

%end

%ctor {
    @try {
        // Add method to SBIconListFlowExtendedLayout for maximumIconCount calculation
        class_addMethod(objc_getClass("SBIconListFlowExtendedLayout"), @selector(maximumIconCount), (IMP)&SBIconListFlowExtendedLayout_maximumIconCount, "Q@:");
        
        NSLog(@"IconOrder: iOS Version - %@", [[UIDevice currentDevice] systemVersion]);
        NSLog(@"IconOrder: SBIconListFlowExtendedLayout exists - %d", objc_getClass("SBIconListFlowExtendedLayout") != nil);
        NSLog(@"IconOrder: maximumIconCount method exists - %d", [objc_getClass("SBIconListFlowExtendedLayout") instancesRespondToSelector:@selector(maximumIconCount)]);
        
        %init;
    } @catch (NSException *exception) {
        NSLog(@"IconOrder: Exception in ctor - %@", exception);
    }
}
