//
//  BRMyScene.h
//  SpaceCannon2
//

//  Copyright (c) 2014 Brandon Richey. All rights reserved.
//

#import <SpriteKit/SpriteKit.h>

@interface BRMyScene : SKScene <SKPhysicsContactDelegate>

@property (nonatomic) int ammo;
@property (nonatomic) int score;

@end
