//
//  VoiceVimViewController.h
//  VoiceVim
//
//  Created by VICTORL on 11/23/13.
//
//

#import <UIKit/UIKit.h>
#import <Slt/Slt.h>

@class PocketsphinxController;
@class FliteController;
#import <OpenEars/OpenEarsEventsObserver.h>

@interface VoiceVimViewController : UIViewController <OpenEarsEventsObserverDelegate> {
	Slt *slt;
	OpenEarsEventsObserver *openEarsEventsObserver;
	PocketsphinxController *pocketsphinxController;
	FliteController *fliteController;
    
    NSString *pathToGrammarToStartAppWith;
	NSString *pathToDictionaryToStartAppWith;
}

@property (nonatomic, strong) Slt *slt;

@property (nonatomic, strong) OpenEarsEventsObserver *openEarsEventsObserver;
@property (nonatomic, strong) PocketsphinxController *pocketsphinxController;
@property (nonatomic, strong) FliteController *fliteController;

@property (nonatomic, copy) NSString *pathToGrammarToStartAppWith;
@property (nonatomic, copy) NSString *pathToDictionaryToStartAppWith;

@end
