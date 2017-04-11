//
//  NSDictionary+Utils.m
//  MyAllianz
//
//  Created by Guido Sabatini on 28/09/16.
//  Copyright © 2016 com.sysdata. All rights reserved.
//

#import "NSDictionary+Utils.h"

@implementation NSDictionary (Utils)

- (NSDictionary *)pruneNullValues
{
    NSMutableDictionary *dictionaryCopy = [self mutableCopy];
    for (NSString *key in [self allKeys])
    {
        id object = [self objectForKey:key];
        if ([object isKindOfClass:[NSDictionary class]])
        {
            NSDictionary* prunedDict = [(NSDictionary *)object pruneNullValues];
            [dictionaryCopy setObject:prunedDict forKey:key];
        }
        else if([object isKindOfClass:[NSArray class]])
        {
            NSMutableArray* arrayCopy = [(NSArray*) object mutableCopy];
            for(id subobject in object)
            {
                if([subobject isKindOfClass:[NSDictionary class]])
                {
                    [arrayCopy replaceObjectAtIndex:[arrayCopy indexOfObject:subobject] withObject:[subobject pruneNullValues]];
                }
            }
            [dictionaryCopy setObject:arrayCopy forKey:key];
        }
        else if ((NSString*)object == (id)[NSNull null])
        {
            [dictionaryCopy removeObjectForKey:key];
        }
    }
    return dictionaryCopy;
}

@end
