//
//  BOXUserAvatarRequest.m
//  BoxContentSDK
//

#import "BOXRequest_Private.h"
#import "BOXUserAvatarRequest.h"

#import "BOXAPIDataOperation.h"

@interface BOXUserAvatarRequest ()

@property (nonatomic, readonly, strong) NSOutputStream *outputStream;

@end

@implementation BOXUserAvatarRequest

- (instancetype)initWithUserID:(NSString *)userID
{
    if (self = [super init]) {
        _userID = userID;
        _outputStream = [[NSOutputStream alloc] initToMemory];

        _avatarType = BOXAvatarTypeUnspecified;
    }

    return self;
}

- (BOXAPIOperation *)createOperation
{
    NSURL *URL = [self URLWithResource:BOXAPIResourceUsers
                                    ID:self.userID
                           subresource:BOXAPISubresourceAvatar
                                 subID:nil];

    NSMutableDictionary *queryParameters = [NSMutableDictionary dictionary];

    NSString *avatarTypeString = nil;
    switch (self.avatarType) {
        case BOXAvatarTypeSmall:
            avatarTypeString = @"small";
            break;
        case BOXAvatarTypeLarge:
            avatarTypeString = @"large";
            break;
        case BOXAvatarTypeProfile:
            avatarTypeString = @"profile";
            break;
        case BOXAvatarTypeUnspecified:
        default:
            break;
    }
    if ([avatarTypeString length] > 0) {
        queryParameters[BOXAPIParameterKeyAvatarType] = avatarTypeString;
    }

    BOXAPIDataOperation *dataOperation = [self dataOperationWithURL:URL
                                                         HTTPMethod:BOXAPIHTTPMethodGET
                                              queryStringParameters:queryParameters
                                                     bodyDictionary:nil
                                                       successBlock:nil
                                                       failureBlock:nil];
    dataOperation.modelID = self.userID;
    dataOperation.outputStream = self.outputStream;
    dataOperation.isSmallDownloadOperation = YES;

    return dataOperation;
}

- (void)performRequestWithProgress:(BOXProgressBlock)progressBlock completion:(BOXImageBlock)completionBlock
{
    if (completionBlock) {
        BOOL isMainThread = [NSThread isMainThread];
        BOXAPIDataOperation *dataOperation = (BOXAPIDataOperation *)self.operation;

        if (progressBlock) {
            dataOperation.progressBlock = ^(long long expectedTotalBytes, unsigned long long bytesReceived) {
                [BOXDispatchHelper callCompletionBlock:^{
                    progressBlock(bytesReceived, expectedTotalBytes);
                } onMainThread:isMainThread];
            };
        }

        NSOutputStream *outputStream = self.outputStream;
        dataOperation.successBlock = ^(NSString *modelID, long long expectedTotalBytes) {
            NSData *data = [outputStream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
            UIImage *image = [UIImage imageWithData:data
                                              scale:[[UIScreen mainScreen] scale]];
            [BOXDispatchHelper callCompletionBlock:^{
                completionBlock(image, nil);
            } onMainThread:isMainThread];
        };
        dataOperation.failureBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
            [BOXDispatchHelper callCompletionBlock:^{
                completionBlock(nil, error);
            } onMainThread:isMainThread];
        };
        [self performRequest];
    }
}

@end
