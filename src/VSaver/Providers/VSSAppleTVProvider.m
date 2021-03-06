//
//  VSSAppleTVProvider.m
//  VSaver
//
//  Created by Jarek Pendowski on 07/05/2018.
//  Copyright © 2018 Jarek Pendowski. All rights reserved.
//

#import "VSSAppleTVProvider.h"
#import "NSObject+Extended.h"
#import "NSArray+Extended.h"

#define JSONURL [NSURL URLWithString: @"http://a1.phobos.apple.com/us/r1000/000/Features/atv/AutumnResources/videos/entries.json"]

@interface VSSAppleItem: NSObject
    @property (nonatomic) NSInteger index;
    @property (nonnull, nonatomic, copy) NSString *label;
    @property (nonnull, nonatomic, strong) NSURL *url;
@end

@implementation VSSAppleItem
    - (instancetype) initWithIndex:(NSInteger)index label:(NSString *)label url:(NSURL *)url {
        self = [super init];
        if (self) {
            self.index = index;
            self.label = label;
            self.url = url;
        }
        return self;
    }
@end

@interface VSSAppleTVProvider ()
    @property (nonnull, nonatomic, strong) NSMutableArray<VSSAppleItem *> *cache;
@end

@implementation VSSAppleTVProvider
    
- (instancetype)init {
    self = [super init];
    if (self) {
        self.cache = [NSMutableArray array];
    }
    return self;
}
    
- (NSString *)name {
    return @"AppleTV";
}

- (void)getVideoFromURL:(NSURL * _Nonnull)url completion:(void (^ _Nonnull)(VSSURLItem * _Nullable))completion {
    if (![url.scheme isEqualToString: @"appletv"]) {
        completion([[VSSURLItem alloc] initWithTitle:url.absoluteString url:url]);
        return;
    }
    
    NSString *urlIndexString = url.host ?: url.fragment;
    NSInteger urlIndex = urlIndexString.length > 0 ? [urlIndexString integerValue] : -1;
    if (urlIndexString.length > 0 && self.cache.count > 0) {
        completion([self getItemAtIndex:urlIndex]);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    [[session dataTaskWithURL:JSONURL completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!data || error) {
            completion(nil);
            return;
        }
        
        NSError *jsonError;
        NSArray<NSDictionary *> *jsonDictionaries = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
        NSArray<NSDictionary *> *assets = [jsonDictionaries vss_flatMap:^id _Nullable(NSDictionary * _Nonnull obj) {
            return VSSAS(obj[@"assets"], NSArray);;
        }];
        
        if (!assets || jsonError) {
            completion(nil);
            return;
        }
        
        for (NSDictionary *dic in assets) {
            NSString *urlString = dic[@"url"];
            if (urlString) {
                NSURL *url = [NSURL URLWithString:urlString];
                NSString *label = dic[@"accessibilityLabel"] ?: @"";
                NSInteger index = strongSelf.cache.count + 1;
                
                [strongSelf.cache addObject:[[VSSAppleItem alloc] initWithIndex:index label:label url:url]];
            }
        }
        
        if (strongSelf.cache.count == 0) {
            completion(nil);
            return;
        }
        
        completion([strongSelf getItemAtIndex:urlIndex]);
    }] resume];
}
    
- (BOOL)isValidURL:(NSURL * _Nonnull)url {
    return  [url.host containsString:@"apple.com"] || [url.scheme isEqualToString:@"appletv"];
}
    
#pragma mark - Private
    
- (VSSURLItem *)getItemAtIndex: (NSInteger)index {
    NSInteger cacheIndex = index;
    if (index < 0 || self.cache.count <= index) {
        cacheIndex = arc4random() % (self.cache.count - 1);
    }
    VSSAppleItem *item = self.cache[cacheIndex];
    return [[VSSURLItem alloc] initWithTitle:[NSString stringWithFormat:@"#%ld %@", item.index, item.label] url:item.url];
}
    
@end
