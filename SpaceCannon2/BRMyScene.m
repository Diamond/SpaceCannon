//
//  BRMyScene.m
//  SpaceCannon2
//
//  Created by Brandon Richey on 7/12/14.
//  Copyright (c) 2014 Brandon Richey. All rights reserved.
//

#import "BRMyScene.h"

@implementation BRMyScene {
    SKNode *_mainLayer;
    SKSpriteNode *_cannon;
    BOOL _didShoot;
}

static const CGFloat SHOOT_SPEED     = 1000.0f;
static const CGFloat HALO_LOW_ANGLE  = 200.0f * M_PI / 180.0f;
static const CGFloat HALO_HIGH_ANGLE = 340.0f * M_PI / 180.0f;
static const CGFloat HALO_SPEED      = 100.0f;

static const uint32_t HALO_CATEGORY = 0x1 << 0;
static const uint32_t BALL_CATEGORY = 0x1 << 1;
static const uint32_t EDGE_CATEGORY = 0x1 << 2;

static inline CGVector radiansToVector(CGFloat radians)
{
    CGVector vector;
    vector.dx = cosf(radians);
    vector.dy = sinf(radians);
    return vector;
}

static inline CGFloat randomInRange(CGFloat low, CGFloat high)
{
    CGFloat value = arc4random_uniform(UINT32_MAX) / (CGFloat)UINT32_MAX;
    return value * (high - low) + low;
}

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
        self.physicsWorld.gravity = CGVectorMake(0.0f, 0.0f);
        self.physicsWorld.contactDelegate = self;
        _didShoot = FALSE;
        
        SKSpriteNode *background = [SKSpriteNode spriteNodeWithImageNamed:@"Starfield"];
        background.position = CGPointZero;
        background.anchorPoint = CGPointZero;
        background.blendMode = SKBlendModeReplace;
        [self addChild:background];
        
        _mainLayer = [[SKNode alloc] init];
        [self addChild:_mainLayer];
        
        SKNode *leftEdge = [[SKNode alloc] init];
        leftEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height)];
        leftEdge.position = CGPointZero;
        leftEdge.physicsBody.categoryBitMask = EDGE_CATEGORY;
        
        SKNode *rightEdge = [[SKNode alloc] init];
        rightEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height)];
        rightEdge.position = CGPointMake(self.size.width, 0.0f);
        rightEdge.physicsBody.categoryBitMask = EDGE_CATEGORY;
        
        [self addChild:leftEdge];
        [self addChild:rightEdge];
        
        _cannon = [SKSpriteNode spriteNodeWithImageNamed:@"Cannon"];
        _cannon.position = CGPointMake(self.size.width * 0.5, 0.0f);
        [_mainLayer addChild:_cannon];
        
        SKAction *rotateCannon = [SKAction sequence:@[[SKAction rotateByAngle:M_PI duration:2],[SKAction rotateByAngle:-M_PI duration:2]]];
        [_cannon runAction:[SKAction repeatActionForever:rotateCannon]];
        
        // Create spawn halo actions
        SKAction *spawnHalo = [SKAction sequence:@[
                                                   [SKAction waitForDuration:2 withRange: 1],
                                                   [SKAction performSelector:@selector(spawnHalo) onTarget:self]
                                                   ]];
        [self runAction:[SKAction repeatActionForever:spawnHalo]];
    }
    return self;
}

-(void)shoot
{
    SKSpriteNode *ball = [SKSpriteNode spriteNodeWithImageNamed:@"Ball"];
    CGVector rotationVector = radiansToVector(_cannon.zRotation);
    ball.name = @"ball";
    ball.position = CGPointMake(_cannon.position.x + (_cannon.size.width * 0.5 * rotationVector.dx),
                                _cannon.position.y + (_cannon.size.width * 0.5 * rotationVector.dy));
    [_mainLayer addChild:ball];
    
    ball.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:6.0f];
    ball.physicsBody.velocity = CGVectorMake(rotationVector.dx * SHOOT_SPEED, rotationVector.dy * SHOOT_SPEED);
    ball.physicsBody.restitution = 1.0f;
    ball.physicsBody.linearDamping = 0.0f;
    ball.physicsBody.friction = 0.0f;
    ball.physicsBody.categoryBitMask  = BALL_CATEGORY;
    ball.physicsBody.collisionBitMask = EDGE_CATEGORY;
    //ball.physicsBody.contactTestBitMask = HALO_CATEGORY;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    for (UITouch *touch in touches) {
        _didShoot = TRUE;
    }
}

-(void)didSimulatePhysics
{
    if (_didShoot) {
        _didShoot = FALSE;
        [self shoot];
    }
    
    [_mainLayer enumerateChildNodesWithName:@"ball" usingBlock:^(SKNode *node, BOOL *stop) {
        if (!CGRectContainsPoint(self.frame, node.position)) {
            [node removeFromParent];
        }
    }];
}

-(void)spawnHalo
{
    SKSpriteNode *halo = [SKSpriteNode spriteNodeWithImageNamed:@"Halo"];
    halo.position = CGPointMake(randomInRange(halo.size.width / 2, self.size.width - halo.size.width / 2),
                                self.size.height + halo.size.height / 2);
    halo.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:16.0f];
    CGVector direction = radiansToVector(randomInRange(HALO_LOW_ANGLE, HALO_HIGH_ANGLE));
    halo.physicsBody.velocity = CGVectorMake(direction.dx * HALO_SPEED, direction.dy * HALO_SPEED);
    halo.physicsBody.restitution = 1.0f;
    halo.physicsBody.linearDamping = 0.0f;
    halo.physicsBody.friction = 0.0f;
    halo.physicsBody.categoryBitMask = HALO_CATEGORY;
    halo.physicsBody.collisionBitMask = EDGE_CATEGORY;
    halo.physicsBody.contactTestBitMask = BALL_CATEGORY;
    [self addChild:halo];
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

-(void)didBeginContact:(SKPhysicsContact *)contact
{
    SKPhysicsBody *firstBody;
    SKPhysicsBody *secondBody;
    
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask) {
        firstBody  = contact.bodyA;
        secondBody = contact.bodyB;
    } else {
        firstBody  = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    if (firstBody.categoryBitMask == HALO_CATEGORY && secondBody.categoryBitMask == BALL_CATEGORY) {
        // Collision between halo and ball
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
    }
}

@end
