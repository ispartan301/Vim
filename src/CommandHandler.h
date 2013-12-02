#import <Foundation/Foundation.h>

@interface CommandHandler : NSObject
@property (nonatomic, strong) NSDictionary *characters;
@property (nonatomic, strong) NSDictionary *commands;
- (NSString *)normalize:(NSString *)hypothesis;
- (NSString *)get:(NSString *)reco;
@end
