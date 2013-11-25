//
//  VoiceVimViewController.m
//  VoiceVim
//
//  Created by VICTORL on 11/23/13.
//
//

#import "VoiceVimViewController.h"

#import <OpenEars/PocketsphinxController.h>
#import <OpenEars/FliteController.h>
#import <OpenEars/LanguageModelGenerator.h>
#import <OpenEars/OpenEarsLogging.h>
#import <OpenEars/AcousticModel.h>

@implementation VoiceVimViewController
@synthesize fliteController;
@synthesize openEarsEventsObserver;
@synthesize slt;

@synthesize pocketsphinxController;

#pragma mark -
#pragma mark Memory Management

- (void)dealloc {
	openEarsEventsObserver.delegate = nil;
}

#pragma mark -
#pragma mark Lazy Allocation

// Lazily allocated PocketsphinxController.
- (PocketsphinxController *)pocketsphinxController {
	if (pocketsphinxController == nil) {
		pocketsphinxController = [[PocketsphinxController alloc] init];
        //pocketsphinxController.verbosePocketSphinx = TRUE; // Uncomment me for verbose debug output
        pocketsphinxController.outputAudio = TRUE;
#ifdef kGetNbest
        pocketsphinxController.returnNbest = TRUE;
        pocketsphinxController.nBestNumber = 5;
#endif
	}
	return pocketsphinxController;
}

// Lazily allocated slt voice.
- (Slt *)slt {
	if (slt == nil) {
		slt = [[Slt alloc] init];
	}
	return slt;
}

// Lazily allocated FliteController.
- (FliteController *)fliteController {
	if (fliteController == nil) {
		fliteController = [[FliteController alloc] init];
        
	}
	return fliteController;
}

// Lazily allocated OpenEarsEventsObserver.
- (OpenEarsEventsObserver *)openEarsEventsObserver {
	if (openEarsEventsObserver == nil) {
		openEarsEventsObserver = [[OpenEarsEventsObserver alloc] init];
	}
	return openEarsEventsObserver;
}

- (void) startListening {
    [self.pocketsphinxController startListeningWithLanguageModelAtPath:self.pathToGrammarToStartAppWith dictionaryAtPath:self.pathToDictionaryToStartAppWith acousticModelAtPath:[AcousticModel pathToModel:@"AcousticModelEnglish"] languageModelIsJSGF:TRUE];
}

#pragma mark -
#pragma mark OpenEarsEventsObserver delegate methods

- (void) pocketsphinxDidReceiveHypothesis:(NSString *)hypothesis recognitionScore:(NSString *)recognitionScore utteranceID:(NSString *)utteranceID {
    
	NSLog(@"The received hypothesis is %@ with a score of %@ and an ID of %@", hypothesis, recognitionScore, utteranceID); // Log it.

	[self.fliteController say:[NSString stringWithFormat:@"You said %@",hypothesis] withVoice:self.slt];
}

#ifdef kGetNbest
- (void) pocketsphinxDidReceiveNBestHypothesisArray:(NSArray *)hypothesisArray { // Pocketsphinx has an n-best hypothesis dictionary.
    NSLog(@"hypothesisArray is %@",hypothesisArray);
}
#endif

- (void) audioSessionInterruptionDidBegin {
	NSLog(@"AudioSession interruption began.");
	[self.pocketsphinxController stopListening];
}

- (void) audioSessionInterruptionDidEnd {
	NSLog(@"AudioSession interruption ended.");
    [self startListening];
	
}

- (void) audioInputDidBecomeUnavailable {
	NSLog(@"The audio input has become unavailable");
	[self.pocketsphinxController stopListening];
}

- (void) audioInputDidBecomeAvailable {
	NSLog(@"The audio input is available");
    [self startListening];
}

- (void) audioRouteDidChangeToRoute:(NSString *)newRoute {
	NSLog(@"Audio route change. The new audio route is %@", newRoute);
	[self.pocketsphinxController stopListening];
    [self startListening];
}

- (void) pocketsphinxDidStartCalibration {
	NSLog(@"Pocketsphinx calibration has started.");
}

- (void) pocketsphinxDidCompleteCalibration {
	NSLog(@"Pocketsphinx calibration is complete.");
    
	self.fliteController.duration_stretch = .9; // Change the speed
	self.fliteController.target_mean = 1.2; // Change the pitch
	self.fliteController.target_stddev = 1.5; // Change the variance
	
    [self.fliteController say:@"Welcome to OpenEars." withVoice:self.slt];
    // The same statement with the pitch and other voice values changed.
	
	self.fliteController.duration_stretch = 1.0; // Reset the speed
	self.fliteController.target_mean = 1.0; // Reset the pitch
	self.fliteController.target_stddev = 1.0; // Reset the variance
}

- (void) pocketsphinxRecognitionLoopDidStart {
    
	NSLog(@"Pocketsphinx is starting up.");
}

- (void) pocketsphinxDidStartListening {
	
	NSLog(@"Pocketsphinx is now listening.");
}

- (void) pocketsphinxDidDetectSpeech {
	NSLog(@"Pocketsphinx has detected speech.");
}

- (void) pocketsphinxDidDetectFinishedSpeech {
	NSLog(@"Pocketsphinx has detected a second of silence, concluding an utterance.");
}

- (void) pocketsphinxDidStopListening {
	NSLog(@"Pocketsphinx has stopped listening.");
}

- (void) pocketsphinxDidSuspendRecognition {
	NSLog(@"Pocketsphinx has suspended recognition.");
}

- (void) pocketsphinxDidResumeRecognition {
	NSLog(@"Pocketsphinx has resumed recognition.");
}

- (void) pocketsphinxDidChangeLanguageModelToFile:(NSString *)newLanguageModelPathAsString andDictionary:(NSString *)newDictionaryPathAsString {
	NSLog(@"Pocketsphinx is now using the following language model: \n%@ and the following dictionary: %@",newLanguageModelPathAsString,newDictionaryPathAsString);
}

- (void) fliteDidStartSpeaking {
	NSLog(@"Flite has started speaking");
}

- (void) fliteDidFinishSpeaking {
	NSLog(@"Flite has finished speaking");
}

- (void) pocketSphinxContinuousSetupDidFail {
	NSLog(@"Setting up the continuous recognition loop has failed for some reason, please turn on [OpenEarsLogging startOpenEarsLogging] in OpenEarsConfig.h to learn more.");
}

- (void) shutDown {
    NSLog(@"Hi I'm on thread %@",[NSThread currentThread]);
}

- (void) testRecognitionCompleted {
	NSLog(@"A test file which was submitted for direct recognition via the audio driver is done.");
    [self.pocketsphinxController stopListening];
    
}

//--------------------------------------------------

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
