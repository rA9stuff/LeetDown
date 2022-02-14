//
//  plistModifier.m
//  LeetDown
//
//  Created by rA9stuff on 1.02.2022.
//


#include "plistModifier.h"


void plistModifier::modifyPref(NSString* key, NSString* val) {
    
    NSString* preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary* dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    [dict setValue:val forKey: key];
    [dict writeToFile:preferencePlist atomically:YES];
    
}

NSString* plistModifier::getPref(NSString* key) {
    
    NSString *preferencePlist = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/com.rA9.LeetDownPreferences.plist"];
    NSDictionary *dict=[[NSDictionary alloc] initWithContentsOfFile:preferencePlist];
    return dict[key];
}
