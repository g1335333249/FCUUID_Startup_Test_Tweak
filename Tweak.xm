// FCUUID startup seeding test tweak.
// Intended exclusively for a test build and backend you are authorized to assess.
// This tweak changes only the current app's own Keychain + NSUserDefaults records.
// It does NOT disable server-side verification or hide instrumentation.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>

// CHANGE BOTH lines to match your *second test app*, not the original app.
static NSString *const kTestBundleIdentifier = @"com.nari.digitalAttendance";
// Accepts a raw 32/36-character UUID or an app deviceId prefixed with UID_.
// Put your test value here locally; do not upload a production device ID.
static NSString *const kKnownTestIdentifier = @"UID_nrsud2wr/q8m+8i7uIfUGJOs53U1rroey6Mg8JM1f5h3GVtLZMYWwpgFaknQ0FrLZLU6w";

static NSString *NormalizeFCUUID(NSString *value) {
    if (![value isKindOfClass:[NSString class]]) return nil;
    NSString *s = [value stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([s hasPrefix:@"UID_"]) s = [s substringFromIndex:4];
    s = [s stringByReplacingOccurrencesOfString:@"-" withString:@""];
    if (s.length != 32) return nil;
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:
        @"0123456789abcdefABCDEF"];
    if ([[s stringByTrimmingCharactersInSet:hex] length] != 0) return nil;
    return s; // preserve case exactly; app's login layer adds UID_.
}

static OSStatus SeedCurrentAppFCUUID(NSString *raw) {
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    if (!raw || ![service isEqualToString:kTestBundleIdentifier]) return errSecParam;
    NSData *data = [raw dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: @"fc_uuidForDevice"
    };
    OSStatus status = SecItemUpdate((__bridge CFDictionaryRef)query,
        (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: data});
    if (status == errSecItemNotFound) {
        NSMutableDictionary *item = [query mutableCopy];
        item[(__bridge id)kSecValueData] = data;
        status = SecItemAdd((__bridge CFDictionaryRef)item, NULL);
        if (status == errSecDuplicateItem) {
            status = SecItemUpdate((__bridge CFDictionaryRef)query,
                (__bridge CFDictionaryRef)@{(__bridge id)kSecValueData: data});
        }
    }
    if (status != errSecSuccess) return status;
    [[NSUserDefaults standardUserDefaults] setObject:raw forKey:@"fc_uuidForDevice"];
    return errSecSuccess;
}

static BOOL VerifyCurrentAppFCUUID(NSString *expected) {
    NSString *service = [[NSBundle mainBundle] bundleIdentifier];
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: @"fc_uuidForDevice",
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) return NO;
    NSData *foundData = CFBridgingRelease(result);
    NSString *found = [[NSString alloc] initWithData:foundData encoding:NSUTF8StringEncoding];
    NSString *defaults = [[NSUserDefaults standardUserDefaults] stringForKey:@"fc_uuidForDevice"];
    return [found isEqualToString:expected] && [defaults isEqualToString:expected];
}

// Hook a real application lifecycle method (confirmed in the provided IPA).
// Avoid constructor-time Keychain/FCUUID access; early constructors can cause crashes.
%hook AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    @autoreleasepool {
        NSString *bundle = [[NSBundle mainBundle] bundleIdentifier];
        if ([bundle isEqualToString:kTestBundleIdentifier]) {
            NSString *raw = NormalizeFCUUID(kKnownTestIdentifier);
            if (!raw) {
                NSLog(@"[FCUUID-Test] invalid test identifier (expected 32/36 hex or UID_ form)");
            } else {
                OSStatus status = SeedCurrentAppFCUUID(raw);
                BOOL readbackOK = (status == errSecSuccess) && VerifyCurrentAppFCUUID(raw);
                NSLog(@"[FCUUID-Test] seed status=%d, readback=%@",
                    (int)status, readbackOK ? @"OK" : @"FAILED");
            }
        }
    }
    return %orig;
}
%end
