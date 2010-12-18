//
//  ProfileDataManager.h
//  Chicken of the VNC
//
//  Created by Jared McIntyre on 8/12/04.
//  Copyright 2004 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/** This message indicates that the profile list has changed */
#define ProfileListChangeMsg @"ProfileListChangeMsg"

@class Profile;

@interface ProfileDataManager : NSObject {

@private
	NSMutableDictionary *mProfiles;
    NSMutableDictionary *mProfileDicts;
}

/**
 *  Accessor method to fetch the singleton instance for this class. Use this method
 *  instead of creating an instance of your own.
 *  @return Shared singleton instance of the ProfileDataManager class. */
+ (ProfileDataManager*) sharedInstance;

- (Profile *)defaultProfile;
- (NSString *)defaultProfileName;
- (Profile *)profileForKey:(id) key;
- (BOOL)profileWithNameExists:(NSString *)name;
- (void)setProfile:(Profile*) profile forKey:(id) key;
- (void)removeProfileForKey:(id) key;
- (int)count;
- (void)saveProfile:(Profile *)profile;
- (NSArray*)sortedKeyArray;

@end
