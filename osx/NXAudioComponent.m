//
//  NXAudioComponent.m
//  mameosx
//
//  Created by Dave Dribin on 12/9/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import "NXAudioComponent.h"
#import "NXAudioException.h"

#define THROW_IF NXThrowAudioIfErr

@implementation NXAudioComponent

+ (NSArray *) componentsMatchingType: (OSType) type
                             subType: (OSType) subType
                        manufacturer: (OSType) manufacturer;
{
    ComponentDescription description;
    description.componentType = type;
    description.componentSubType = subType;
    description.componentManufacturer = manufacturer;
    description.componentFlags = 0;
    description.componentFlagsMask = 0;
    
    return [self componentsMatchingDescription: &description];
}

+ (NSArray *) componentsMatchingDescription:
    (ComponentDescription *) description;
{
    long componentCount = CountComponents(description);
    NSMutableArray * components =
        [NSMutableArray arrayWithCapacity: componentCount];
    Component current = 0;
    do
    {
        NSAutoreleasePool * loopPool = [[NSAutoreleasePool alloc] init];
        current = FindNextComponent(current, description);
        if (current != 0)
        {
            NXAudioComponent * component =
            [[NXAudioComponent alloc] initWithComponent: current];
            [components addObject: component];
            [component release];
        }
        [loopPool release];
    } while (current != 0);
    
    return components;
}

+ (void) printComponents;
{
    NSArray * components = [self componentsMatchingType: kAudioUnitType_Effect
                                                subType: 0
                                           manufacturer: 0];
    NSLog(@"component count: %d", [components count]);
    
    NSEnumerator * e = [components objectEnumerator];
    NXAudioComponent * component;
    while (component = [e nextObject])
    {
        ComponentDescription description = [component ComponentDescription];
        NSString * type = (NSString *)
            UTCreateStringForOSType(description.componentType);
        NSString * subType = (NSString *)
            UTCreateStringForOSType(description.componentSubType);
        NSString * manufacturer = (NSString *)
            UTCreateStringForOSType(description.componentManufacturer);
        
        NSLog(@"Compoment %@ by %@: %@ %@ %@", [component name],
              [component manufacturer], type, subType, manufacturer);
        
        [type release];
        [subType release];
        [manufacturer release];
    }
}

- (id) initWithComponent: (Component) component;
{
    self = [super init];
    if (self == nil)
        return nil;
    
    mComponent = component;
    mManufacturer = @"";
    mName = @"";
    
    Handle h1 = NewHandle(4);
    THROW_IF(GetComponentInfo(component, &mDescription, h1, NULL, NULL));
    
    NSString * fullName = (NSString *)
        CFStringCreateWithPascalString(NULL, (const unsigned char*)*h1, kCFStringEncodingMacRoman);
    DisposeHandle(h1);
    
    NSRange colonRange = [fullName rangeOfString: @":"];
    if (colonRange.location != NSNotFound)
    {
        mManufacturer = [fullName substringToIndex: colonRange.location];
        mName = [fullName substringFromIndex: colonRange.location + 1];
        mName = [mName stringByTrimmingCharactersInSet:
            [NSCharacterSet whitespaceCharacterSet]];
        
        [mManufacturer retain];
        [mName retain];
    }
    else
    {
        mManufacturer = @"";
        mName = [fullName copy];
    }
    
    [fullName release];
    
    return self;
}

- (Component) Component;
{
    return mComponent;
}

- (ComponentDescription) ComponentDescription;
{
    return mDescription;
}

- (NSString *) manufacturer;
{
    return mManufacturer;
}

- (NSString *) name;
{
    return mName;
}


@end
