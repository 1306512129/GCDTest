//  PhotoManager.m
//  PhotoFilter
//
//  Created by A Magical Unicorn on A Sunday Night.
//  Copyright (c) 2014 Derek Selander. All rights reserved.
//

@import CoreImage;
@import AssetsLibrary;
#import "PhotoManager.h"

@interface PhotoManager ()
@property (nonatomic, strong) NSMutableArray *photosArray;
@property (nonatomic,strong) dispatch_queue_t concurrentPhotoQueue;
@end

@implementation PhotoManager

+ (instancetype)sharedManager
{
    static PhotoManager *sharedPhotoManager = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedPhotoManager = [[PhotoManager alloc]init];
        sharedPhotoManager.photosArray = [NSMutableArray array];
        
        //自定义的并行队列
        /*
         *dispatch_queue_create 第一个参数 反向DNS样式命名惯例；确保它是描述性的，将有助于调试  第二参数指定你的队列是串行还是并发。
         *当你在网上搜索例子时，你会经常看人们传递 0 或者 NULL 给 dispatch_queue_create 的第二个参数。这是一个创建串行队列的过时方式；明确你的参数总是更好。
         */
        sharedPhotoManager.concurrentPhotoQueue = dispatch_queue_create("com.selander.GooglyPuff.photoQueue", DISPATCH_QUEUE_CONCURRENT);
    });
   
    return sharedPhotoManager;
}

//*****************************************************************************/
#pragma mark - Unsafe Setter/Getters
//*****************************************************************************/

- (NSArray *)photos
{
    __block NSArray *array;
    dispatch_sync(self.concurrentPhotoQueue, ^{
        array = [NSArray arrayWithArray:_photosArray];
    });
    return array;
}

- (void)addPhoto:(Photo *)photo
{
    if (photo) {
        dispatch_barrier_async(self.concurrentPhotoQueue, ^{
            [_photosArray addObject:photo];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self postContentAddedNotification];
            });
        });
    }
    
}

//*****************************************************************************/
#pragma mark - Public Methods
//*****************************************************************************/

- (void)downloadPhotosWithCompletionBlock:(BatchPhotoDownloadingCompletionBlock)completionBlock
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __block NSError *error;
        dispatch_group_t downloadGroup = dispatch_group_create();
        dispatch_apply(3,dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(size_t i) {
            
            NSURL *url;
            switch (i) {
                case 0:
                    url = [NSURL URLWithString:kOverlyAttachedGirlfriendURLString];
                    break;
                case 1:
                    url = [NSURL URLWithString:kSuccessKidURLString];
                    break;
                case 2:
                    url = [NSURL URLWithString:kLotsOfFacesURLString];
                    break;
                default:
                    break;
                    
                    dispatch_group_enter(downloadGroup);
                    
                    Photo *photo = [[Photo alloc] initwithURL:url
                                          withCompletionBlock:^(UIImage *image, NSError *_error) {
                                              if (_error) {
                                                  error = _error;
                                              }
                                              dispatch_group_leave(downloadGroup);
                                          }];
                    
                    [[PhotoManager sharedManager] addPhoto:photo];
            }
        });
            
        dispatch_group_notify(downloadGroup, dispatch_get_main_queue(), ^{
            
            if (completionBlock) {
                completionBlock(error);
            }
            
        });
       
        
    });
   
}

//*****************************************************************************/
#pragma mark - Private Methods
//*****************************************************************************/

- (void)postContentAddedNotification
{
    static NSNotification *notification = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        notification = [NSNotification notificationWithName:kPhotoManagerAddedContentNotification object:nil];
    });
    
    [[NSNotificationQueue defaultQueue] enqueueNotification:notification postingStyle:NSPostASAP coalesceMask:NSNotificationCoalescingOnName forModes:nil];
}

@end
