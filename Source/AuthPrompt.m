/* AuthPrompt.m
 * Copyright (C) 2011 Dustin Cartwright
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *
 */

#import <AuthPrompt.h>

@implementation AuthPrompt

- (id)initWithDelegate:(id<AuthPromptDelegate>)aDelegate
{
    if (self = [super init]) {
        delegate = aDelegate;
        [NSBundle loadNibNamed:@"AuthPrompt" owner:self];
    }
    return self;
}

- (void)runSheetOnWindow:(NSWindow *)window
{
    [NSApp beginSheet:panel modalForWindow:window modalDelegate:self
        didEndSelector:@selector(passwordEnteredFor:returnCode:contextInfo:)
        contextInfo:nil];
    [self retain];
}

- (void)stopSheet
{
    [NSApp endSheet:panel];
}

- (IBAction)enterPassword:(id)sender
{
    [delegate authPasswordEntered:[passwordField stringValue]];
    [NSApp endSheet:panel];
}

- (IBAction)cancel:(id)sender
{
    [NSApp endSheet:panel];
    [delegate authCancelled];
}

- (IBAction)passwordEnteredFor:(NSWindow *)wind returnCode:(int)retCode
    contextInfo:(void *)info
{
    [panel orderOut:self];
    [self autorelease];
}

@end
