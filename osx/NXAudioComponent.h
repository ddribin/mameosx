//
//  NXAudioComponent.h
//  mameosx
//
//  Created by Dave Dribin on 12/9/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AudioUnit/AudioUnit.h>

@interface NXAudioComponent : NSObject
{
    Component mComponent;
    ComponentDescription mDescription;
    NSString * mManufacturer;
    NSString * mName;
}

+ (NSArray *) componentsMatchingType: (OSType) type
                             subType: (OSType) subType
                        manufacturer: (OSType) manufacturer;

+ (NSArray *) componentsMatchingDescription:
    (ComponentDescription *) description;

+ (void) printComponents;

- (id) initWithComponent: (Component) component;

- (Component) Component;

- (ComponentDescription) ComponentDescription;

- (NSString *) manufacturer;

- (NSString *) name;

@end
