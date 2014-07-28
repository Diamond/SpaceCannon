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
    SKSpriteNode *_ammoDisplay;
    BOOL _didShoot;
}

static const CGFloat SHOOT_SPEED     = 1000.0f;
static const CGFloat HALO_LOW_ANGLE  = 200.0f * M_PI / 180.0f;
static const CGFloat HALO_HIGH_ANGLE = 340.0f * M_PI / 180.0f;
static const CGFloat HALO_SPEED      = 100.0f;

static const uint32_t HALO_CATEGORY    = 0x1 << 0;
static const uint32_t BALL_CATEGORY    = 0x1 << 1;
static const uint32_t EDGE_CATEGORY    = 0x1 << 2;
static const uint32_t SHIELD_CATEGORY  = 0x1 << 3;
static const uint32_t LIFEBAR_CATEGORY = 0x1 << 4;

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
        leftEdge.physicsBody.contactTestBitMask = BALL_CATEGORY;
        
        SKNode *rightEdge = [[SKNode alloc] init];
        rightEdge.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointZero toPoint:CGPointMake(0.0, self.size.height)];
        rightEdge.position = CGPointMake(self.size.width, 0.0f);
        rightEdge.physicsBody.categoryBitMask = EDGE_CATEGORY;
        rightEdge.physicsBody.contactTestBitMask = BALL_CATEGORY;
        
        [self addChild:leftEdge];
        [self addChild:rightEdge];
        
        _cannon = [SKSpriteNode spriteNodeWithImageNamed:@"Cannon"];
        _cannon.position = CGPointMake(self.size.width * 0.5, 0.0f);
        [self addChild:_cannon];
        
        SKAction *rotateCannon = [SKAction sequence:@[[SKAction rotateByAngle:M_PI duration:2],[SKAction rotateByAngle:-M_PI duration:2]]];
        [_cannon runAction:[SKAction repeatActionForever:rotateCannon]];
        
        // Create spawn halo actions
        SKAction *spawnHalo = [SKAction sequence:@[
                                                   [SKAction waitForDuration:2 withRange: 1],
                                                   [SKAction performSelector:@selector(spawnHalo) onTarget:self]
                                                   ]];
        [self runAction:[SKAction repeatActionForever:spawnHalo]];
        
        _ammoDisplay = [SKSpriteNode spriteNodeWithImageNamed:@"Ammo5"];
        _ammoDisplay.anchorPoint = CGPointMake(0.5f, 0.0f);
        _ammoDisplay.position    = _cannon.position;
        [self addChild:_ammoDisplay];
        
        
        SKAction *incrementAmmo = [SKAction sequence:@[[SKAction waitForDuration:1], [SKAction runBlock:^{
            self.ammo++;
        }]]];
        [self runAction:[SKAction repeatActionForever:incrementAmmo]];
        
        [self newGame];
    }
    return self;
}

-(void)newGame
{
    [_mainLayer removeAllChildren];
    
    self.ammo = 5;
    
    for (int i = 0; i < 6; i++) {
        SKSpriteNode *shield = [SKSpriteNode spriteNodeWithImageNamed:@"Block"];
        shield.position = CGPointMake(35 + (50 * i), 90);
        shield.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:CGSizeMake(42, 9)];
        shield.physicsBody.categoryBitMask  = SHIELD_CATEGORY;
        shield.physicsBody.collisionBitMask = 0;
        shield.name = @"shield";
        [_mainLayer addChild:shield];
    }
    
    SKSpriteNode *lifeBar = [SKSpriteNode spriteNodeWithImageNamed:@"BlueBar"];
    lifeBar.position = CGPointMake(self.size.width / 2, 70);
    lifeBar.physicsBody = [SKPhysicsBody bodyWithEdgeFromPoint:CGPointMake(-lifeBar.size.width / 2, 0) toPoint:CGPointMake(lifeBar.size.width / 2, 0)];
    lifeBar.physicsBody.categoryBitMask = LIFEBAR_CATEGORY;
    lifeBar.physicsBody.collisionBitMask = 0;
    lifeBar.name = @"lifebar";
    [_mainLayer addChild:lifeBar];
}

-(void)setAmmo:(int)ammo
{
    if (ammo >= 0 && ammo <= 5) {
        _ammo = ammo;
        _ammoDisplay.texture = [SKTexture textureWithImageNamed:[NSString stringWithFormat:@"Ammo%d", ammo]];
    }
}

-(void)shoot
{
    if (self.ammo <= 0) {
        return;
    }
    self.ammo--;
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
    halo.physicsBody.contactTestBitMask = BALL_CATEGORY | SHIELD_CATEGORY | LIFEBAR_CATEGORY;
    halo.name = @"halo";
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
        [self addExplosion:firstBody.node.position withName:@"HaloExplosion"];
        
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
    }
    
    if (firstBody.categoryBitMask == BALL_CATEGORY && secondBody.categoryBitMask == EDGE_CATEGORY) {
        [self addExplosion:contact.contactPoint withName:@"BallExplosion"];
    }
    
    if (firstBody.categoryBitMask == HALO_CATEGORY && secondBody.categoryBitMask == SHIELD_CATEGORY) {
        [self addExplosion:firstBody.node.position withName:@"HaloExplosion"];
        
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
    }
    
    if (firstBody.categoryBitMask == HALO_CATEGORY && secondBody.categoryBitMask == LIFEBAR_CATEGORY) {
        [self addExplosion:firstBody.node.position withName:@"LifeBarExplosion"];
        
        [firstBody.node removeFromParent];
        [secondBody.node removeFromParent];
        
        [self gameOver];
    }
}

-(void)gameOver
{
    [_mainLayer enumerateChildNodesWithName:@"halo" usingBlock:^(SKNode *node, BOOL *stop) {
        [self addExplosion:node.position withName:@"HaloExplosion"];
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"ball" usingBlock:^(SKNode *node, BOOL *stop) {
        [self addExplosion:node.position withName:@"BallExplosion"];
    }];
    
    [_mainLayer enumerateChildNodesWithName:@"shield" usingBlock:^(SKNode *node, BOOL *stop) {
        [self addExplosion:node.position withName:@"BallExplosion"];
    }];
    
    [self performSelector:@selector(newGame) withObject:nil afterDelay:1.5f];
}

-(void)addExplosion:(CGPoint)position withName:(NSString*)name
{
    NSString *explosionPath = [[NSBundle mainBundle] pathForResource:name ofType:@"sks"];
    SKEmitterNode *explosion = [NSKeyedUnarchiver unarchiveObjectWithFile:explosionPath];
    
    explosion.position = position;
    [_mainLayer addChild:explosion];
    
    SKAction *removeExplosion = [SKAction sequence:@[[SKAction waitForDuration:1.5f], [SKAction removeFromParent]]];
    [explosion runAction:removeExplosion];
}

@end
