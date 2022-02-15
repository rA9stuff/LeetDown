//
//  plistModifier.h
//  LeetDown
//
//  Created by rA9stuff on 3.02.2022.
//

#ifndef plistModifier_h
#define plistModifier_h

#include <iostream>
#import <Foundation/Foundation.h>


class plistModifier {
       
public:
    void modifyPref(NSString* key, NSString* val);
    NSString* getPref(NSString* key);
};


#endif /* plistModifier_h */
