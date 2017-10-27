// Copyright 2017 Sysdata S.p.A.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "NSDictionary+Docker.h"

@implementation NSDictionary (Docker)

- (NSDictionary *)pruneNullValues
{
    NSMutableDictionary *dictionaryCopy = [self mutableCopy];
    for (NSString *key in [self allKeys])
    {
        id object = [self objectForKey:key];
        if ([object isKindOfClass:[NSDictionary class]])
        {
            NSDictionary* prunedDict = [(NSDictionary *)object pruneNullValues];
            if(prunedDict.allKeys.count > 0)
            {
                [dictionaryCopy setObject:prunedDict forKey:key];
            }
            else
            {
                [dictionaryCopy removeObjectForKey:key];
            }
        }
        else if([object isKindOfClass:[NSArray class]])
        {
            NSMutableArray* arrayCopy = [(NSArray*) object mutableCopy];
            for(id subobject in object)
            {
                if([subobject isKindOfClass:[NSDictionary class]])
                {
                    NSDictionary* prunedDict = [(NSDictionary *)subobject pruneNullValues];
                    if(prunedDict.allKeys.count > 0)
                    {
                        [arrayCopy replaceObjectAtIndex:[arrayCopy indexOfObject:subobject] withObject:prunedDict];
                    }
                    else
                    {
                        [arrayCopy removeObjectAtIndex:[arrayCopy indexOfObject:subobject]];
                    }
                }
            }
            [dictionaryCopy setObject:arrayCopy forKey:key];
        }
        else if (object == (id)[NSNull null])
        {
            [dictionaryCopy removeObjectForKey:key];
        }
    }
    return dictionaryCopy;
}

@end
