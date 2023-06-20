//
//  PlistUtils.h
//  LeetDown
//
//  Created by rA9stuff on 3.02.2022.
//

#ifndef PlistUtils_h
#define PlistUtils_h

#include <iostream>
#import <Foundation/Foundation.h>


class PlistUtils {
       
public:
    void modifyPref(NSString* key, NSString* val);
    NSString* getPref(NSString* key);
};


#endif /* PlistUtils_h */
