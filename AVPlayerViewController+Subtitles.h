//
//  AVPlayerViewController+Subtitles.h
//  LiveClass
//
//  Created by wujianbo on 16/10/28.
//  Copyright © 2016年 chaoui. All rights reserved.
//

#import <AVKit/AVKit.h>

@interface AVPlayerViewController (Subtitles)

@property (nonatomic, readonly, getter=subtitleLabel) UILabel * _Nullable subtitleLabel;

- (AVPlayerViewController* _Nonnull)addSubtitles;

- (void)showSubtitlesWithFile:(NSURL * _Nonnull)srtFilePath;
- (void)showSubtitlesWithContent:(NSString * _Nonnull)srtContent;

//In case sometimes you need update subtitleLabel immediately
- (void)refreshSubtitleLabel;

@end
