#import "CommandHandler.h"

@implementation CommandHandler

- (id)init {
    self = [super init];
    self.characters = @{
        @"colon" : @":",
        @"dollor" : @"$",
        @"percent" : @"%",
        @"backslash" : @"\\",
        @"slash" : @"/",
        @"caret" : @"^",
        @"exclamation" : @"!",
    };
    self.commands = @{
        @"insert" : @"i",
        @"escape" : @"\\\\",
        @"top" : @"gg",
        @"bottom" : @"G",
        @"visual" : @"V",
        @"set" : @":set ",
        @"copy" : @"yy",
        @"paste" : @"p",
        @"cut" : @"dd",
        @"search" : @"/",
        @"replace" : @":%s/",
        @"edit" : @":edit ",
        @"help" : @":help ",
        @"undo" : @"u",
        @"redo" : @":red\r",
        @"next" : @"n",
        @"previous" : @"N",
        @"left" : @"h",
        @"right" : @"l",
        @"up" : @"k",
        @"down" : @"j",
        @"open" : @":o ",
        @"save" : @":w ",
        @"exit" : @":q\r",
        @"set paste" : @":set paste\r",
        @"set no paste" : @":set nopaste\r",
        @"set ignore case" : @":set ic\r",
        @"set no ignore case" : @":set noic\r",
        @"set number" : @":set nu\r",
        @"set no number" : @":set nonu\r",
        @"set ruler" : @":set ruler\r",
        @"set no ruler" : @":set noruler\r",
        @"open sample script" : @":o ../VoiceVim.app/sample.pl\r",
        @"open sample text" : @":o ../VoiceVim.app/sample.txt\r",
    };
    return self;
}

- (NSString *)normalize:(NSString *)hypothesis {

    NSString *reco = [hypothesis lowercaseString];

    if ([self.characters objectForKey:reco]) {
        return reco;
    } else if ([self.commands objectForKey:reco]) {
        return reco;
    }
    
    NSRegularExpression *insertRegex = [NSRegularExpression regularExpressionWithPattern:@"(INSERT|TEXT|WRITE|APPEND)" options:0 error:NULL];
    NSRegularExpression *commandRegex = [NSRegularExpression regularExpressionWithPattern:@"(ESCAPE|COMMAND)" options:0 error:NULL];

    NSRegularExpression *topRegex = [NSRegularExpression regularExpressionWithPattern:@"(TOP|BEGINNING)" options:0 error:NULL];
    NSRegularExpression *bottomRegex = [NSRegularExpression regularExpressionWithPattern:@"(BOTTOM|END)" options:0 error:NULL];
    
    NSRegularExpression *hlRegex = [NSRegularExpression regularExpressionWithPattern:@"(VISUAL|HIGHLIGHT|SELECT)" options:0 error:NULL];
    NSRegularExpression *setRegex = [NSRegularExpression regularExpressionWithPattern:@"(SET|SHOW|HIDE)" options:0 error:NULL];

    NSRegularExpression *copyRegex = [NSRegularExpression regularExpressionWithPattern:@"(COPY)" options:0 error:NULL];
    NSRegularExpression *pasteRegex = [NSRegularExpression regularExpressionWithPattern:@"(PASTE)" options:0 error:NULL];
    NSRegularExpression *cutRegex = [NSRegularExpression regularExpressionWithPattern:@"(CUT|DELETE|REMOVE)" options:0 error:NULL];
    
    NSRegularExpression *searchRegex = [NSRegularExpression regularExpressionWithPattern:@"(SEARCH|FIND)" options:0 error:NULL];
    NSRegularExpression *subRegex = [NSRegularExpression regularExpressionWithPattern:@"(SUBSTITUTE|REPLACE)" options:0 error:NULL];
    
    NSRegularExpression *exitRegex = [NSRegularExpression regularExpressionWithPattern:@"(EXIT|QUIT|GOODBYE|CLOSE|SHUT)" options:0 error:NULL];
    
    
    NSTextCheckingResult *insertMatch = [insertRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    NSTextCheckingResult *commandMatch = [commandRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    
    NSTextCheckingResult *topMatch = [topRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    NSTextCheckingResult *bottomMatch = [bottomRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    
    NSTextCheckingResult *hlMatch = [hlRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    NSTextCheckingResult *setMatch = [setRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    
    NSTextCheckingResult *copyMatch = [copyRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    NSTextCheckingResult *pasteMatch = [pasteRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    NSTextCheckingResult *cutMatch = [cutRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];

    NSTextCheckingResult *searchMatch = [searchRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    NSTextCheckingResult *subMatch = [subRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
    
    NSTextCheckingResult *exitMatch = [exitRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];

    if (insertMatch) {
        reco = @"insert";
    } else if (commandMatch) {
        reco = @"command";
    } else if (topMatch) {
        reco = @"top";
    } else if (bottomMatch) {
        reco = @"bottom";
    } else if (hlMatch) {
        reco = @"visual";
    } else if (setMatch) {
        NSRegularExpression *kbRegex = [NSRegularExpression regularExpressionWithPattern:@"(KEYBOARD)" options:0 error:NULL];
        NSTextCheckingResult *kbMatch = [kbRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
        NSRegularExpression *nuRegex = [NSRegularExpression regularExpressionWithPattern:@"(LINE)" options:0 error:NULL];
        NSTextCheckingResult *nuMatch = [nuRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
        NSRegularExpression *ruRegex = [NSRegularExpression regularExpressionWithPattern:@"(RULER)" options:0 error:NULL];
        NSTextCheckingResult *ruMatch = [ruRegex firstMatchInString:hypothesis options:0 range:NSMakeRange(0, [hypothesis length])];
        if (nuMatch) {
            reco = @"set number";
        } else if (ruMatch) {
            reco = @"set ruler";
        } else if (kbMatch) {
            reco = @"insert";
        } else {
            reco = @"set";
        }
    } else if (copyMatch) {
        reco = @"copy";
    } else if (pasteMatch) {
        reco = @"paste";
    } else if (cutMatch) {
        reco = @"cut";
    } else if (searchMatch) {
        reco = @"search";
    } else if (subMatch) {
        reco = @"replace";
    } else if (exitMatch) {
        reco = @"exit";
    } else {
        reco = NULL;
    }
    return reco;
}

- (NSString *)get:(NSString *)reco {
    NSString *cmd;
    if ([self.characters objectForKey:reco]) {
        cmd = [self.characters objectForKey:reco];
    } else if ([self.commands objectForKey:reco]) {
        cmd = [self.commands objectForKey:reco];
    }

    return cmd;
}

@end
