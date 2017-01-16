//
//  AVPlayerViewController+Subtitles.m
//  LiveClass
//
//  Created by wujianbo on 16/10/28.
//  Copyright © 2016年 chaoui. All rights reserved.
//

#import <objc/runtime.h>
#import <AVFoundation/AVPlayer.h>
#import "AVPlayerViewController+Subtitles.h"

static NSString *FontKey = @"FontKey";
//static NSString *ColorKey = @"ColorKey";
static NSString *SubtitleKey = @"SubtitleKey";
static NSString *SubtitleHeightKey = @"SubtitleHeightKey";
static NSString *PayloadKey = @"PayloadKey";

@interface AVPlayerViewController ()

@property (nonatomic, strong) NSLayoutConstraint *subtitleLabelHeightConstraint;

//- (NSDictionary*)parseSubRip:(NSString*)payload;
//- (void)searchSubtitles:(CMTime)time;

@end

@implementation AVPlayerViewController (Subtitles)

- (AVPlayerViewController* _Nonnull)addSubtitles
{
    [self addSubtitleLabel];
    return self;
}

- (void)showSubtitlesWithFile:(NSURL * _Nonnull)srtFilePath
{
    NSStringEncoding usedEncoding;
    NSString *contents = [NSString stringWithContentsOfURL:srtFilePath usedEncoding:&usedEncoding error:NULL];
    if (contents.length)
    {
        [self showSubtitlesWithContent:contents];
    }
}

- (void)showSubtitlesWithContent:(NSString * _Nonnull)srtContent
{
    NSDictionary *parsedPayload = [self parseSubRip:srtContent];
    objc_setAssociatedObject(self, &PayloadKey, parsedPayload, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    if (parsedPayload && parsedPayload.count && self.player)
    {
        typeof(self) __weak weakSelf = self;
        [self.player addPeriodicTimeObserverForInterval:CMTimeMake(1, 60) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
            [weakSelf searchSubtitles:time];
        }];
    }
}

- (void)refreshSubtitleLabel
{
    [self searchSubtitles:self.player.currentTime];
}

#pragma mark - Custom setter && getter
- (UILabel*)subtitleLabel
{
    return objc_getAssociatedObject(self, &SubtitleKey);
}

- (NSLayoutConstraint*)subtitleLabelHeightConstraint
{
    return objc_getAssociatedObject(self, &SubtitleHeightKey);
}

- (NSDictionary*)parsedPayload
{
    return objc_getAssociatedObject(self, &PayloadKey);
}

#pragma mark - Private methods
- (void)addSubtitleLabel
{
    if (!self.subtitleLabel)
    {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.translatesAutoresizingMaskIntoConstraints = false;
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.numberOfLines = 0;
        label.font = [UIFont boldSystemFontOfSize:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 40.0 : 17.0)];
        label.textColor = [UIColor whiteColor];
        label.numberOfLines = 0;
        label.layer.shadowColor = [UIColor blackColor].CGColor;
        label.layer.shadowOffset = CGSizeMake(1.0, 1.0);
        label.layer.shadowOpacity = 0.8;
        label.layer.shadowRadius = 1.0;
        label.layer.shouldRasterize = true;
        label.layer.rasterizationScale = [UIScreen mainScreen].scale;
        label.lineBreakMode = NSLineBreakByWordWrapping;
        [self.contentOverlayView addSubview:label];
        
        // Position
        NSArray *constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-(20)-[l]-(20)-|" options:0 metrics:nil views:@{@"l":label}];
        [self.contentOverlayView addConstraints:constraints];
        constraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[l]-(15)-|" options:0 metrics:nil views: @{@"l":label}];
        [self.contentOverlayView addConstraints:constraints];
        NSLayoutConstraint *labelHeightConstraint = [NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:30.0];
        [self.contentOverlayView addConstraint:labelHeightConstraint];
        
        objc_setAssociatedObject(self, &SubtitleHeightKey, labelHeightConstraint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &SubtitleKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (NSDictionary*)parseSubRip:(NSString*)payload
{
    // Prepare payload
    NSString *preprocessedPayload = [payload stringByReplacingOccurrencesOfString:@"\n\r\n" withString:@"\n\n"];
    preprocessedPayload = [preprocessedPayload stringByReplacingOccurrencesOfString:@"\n\n\n" withString:@"\n\n"];
    
    // Parsed dict
    NSMutableDictionary *parsed = [[NSMutableDictionary alloc] init];

    // Get groups
    NSString *regexStr = @"(?m)(^[0-9]+)([\\s\\S]*?)(?=\n\n)";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:regexStr options:NSRegularExpressionCaseInsensitive error:NULL];
    NSArray<NSTextCheckingResult *> *matches = [regex matchesInString:preprocessedPayload options:0 range:NSMakeRange(0, preprocessedPayload.length)];
    for (NSTextCheckingResult *m in matches)
    {
        NSString *group = [preprocessedPayload substringWithRange:m.range];
        
        // Get index
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[0-9]+" options:NSRegularExpressionCaseInsensitive error:NULL];
        
        NSArray<NSTextCheckingResult *> *match = [regex matchesInString:group options:0 range:NSMakeRange(0, group.length)];

        NSTextCheckingResult *i = match.firstObject;
        if (!i)
        {
            continue;
        }
        
        NSString *index = [group substringWithRange:i.range];
        
        // Get "from" & "to" time
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\d{1,2}:\\d{1,2}:\\d{1,2},\\d{1,3}" options:NSRegularExpressionCaseInsensitive error:NULL];
        match = [regex matchesInString:group options:0 range:NSMakeRange(0, group.length)];
        if (match.count != 2)
        {
            continue;
        }
        
        NSTextCheckingResult *from = match.firstObject;
        NSTextCheckingResult *to = match.lastObject;
        
        NSTimeInterval h = 0.0, m = 0.0, s = 0.0, c = 0.0;
        
        NSString *fromStr = [group substringWithRange:from.range];
        NSScanner *scanner = [NSScanner scannerWithString:fromStr];
        [scanner scanDouble:&h];
        [scanner scanString:@":" intoString:NULL];
        [scanner scanDouble:&m];
        [scanner scanString:@":" intoString:NULL];
        [scanner scanDouble:&s];
        [scanner scanString:@"," intoString:NULL];
        [scanner scanDouble:&c];
        NSTimeInterval fromTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0);
        
        NSString *toStr = [group substringWithRange:to.range];
        scanner = [NSScanner scannerWithString:toStr];
        [scanner scanDouble:&h];
        [scanner scanString:@":" intoString:NULL];
        [scanner scanDouble:&m];
        [scanner scanString:@":" intoString:NULL];
        [scanner scanDouble:&s];
        [scanner scanString:@"," intoString:NULL];
        [scanner scanDouble:&c];
        NSTimeInterval toTime = (h * 3600.0) + (m * 60.0) + s + (c / 1000.0);
        
        // Get text & check if empty
        NSRange range = NSMakeRange(0, to.range.location + to.range.length + 1);
        if (group.length - range.length <= 0)
        {
            continue;
        }
        NSString *text = [group stringByReplacingCharactersInRange:range withString:@""];
        
        // Create final object
        NSMutableDictionary *final = [[NSMutableDictionary alloc] init];
        [final setObject:@(fromTime) forKey:@"from"];
        [final setObject:@(toTime) forKey:@"to"];
        [final setObject:text forKey:@"text"];
        [parsed setObject:final forKey:index];
    }
    return parsed;
}

- (void)searchSubtitles:(CMTime)time
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(%f >= %K) AND (%f <= %K)", CMTimeGetSeconds(time), @"from", CMTimeGetSeconds(time), @"to"];
    
    NSArray *values = self.parsedPayload.allValues;
    if (values && values.count)
    {
        NSDictionary *result = [values filteredArrayUsingPredicate:predicate].firstObject;
        
        if (!result)
        {
            self.subtitleLabel.text = @"";
            return;
        }
        
        UILabel *label = self.subtitleLabel;
        // Set text
        label.text = [(NSString*)[result objectForKey:@"text"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        // Adjust size
        CGRect rect = [label.text boundingRectWithSize:CGSizeMake(label.bounds.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName:label.font} context:nil];
        self.subtitleLabelHeightConstraint.constant = rect.size.height + 5.0;
    }
    else
    {
        self.subtitleLabel.text = @"";
    }
}

@end
