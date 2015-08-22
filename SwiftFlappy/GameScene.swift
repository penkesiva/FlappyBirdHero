//
//  GameScene.swift
//  SwiftFlappy
//
//  Created by rebeloper on 6/5/14.
//  Copyright (c) 2014 Rebeloper. All rights reserved.
//

import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {
    
    var bird = SKSpriteNode()
    var skyColor = SKColor()
    var verticalPipeGap = 150.0
    var pipeTexture1 = SKTexture()
    var pipeTexture2 = SKTexture()
    var moveAndRemovePipes = SKAction()
    
    let birdCategory: UInt32 = 1 << 0
    let worldCategory: UInt32 = 1 << 1
    let pipeCategory: UInt32 = 1 << 2
    let scoreCategory: UInt32 = 1 << 3
    
    var moving = SKNode()
    var canRestart = false
    var pipes = SKNode()
    
    var scoreLabelNode = SKLabelNode()
    var score = NSInteger()
    
    override func didMoveToView(view: SKView) {
        /* Setup your scene here */
        
        self.addChild(moving)
        moving.addChild(pipes)
        
        /* Gravity value for the bird and the rest of the view; default gravity value is 9.8.
           This sets a lesser gravity of 5.0, so the bird drops slow */
        self.physicsWorld.gravity = CGVectorMake( 0.0, -5.0 )
        self.physicsWorld.contactDelegate = self
        
        /* add skycolor */
        skyColor = SKColor(red:113.0/255.0, green:197.0/255.0, blue:207.0/255.0, alpha:1.0)
        self.backgroundColor = skyColor
        
        /* add bird texture; two flaps */
        var birdTexture1 = SKTexture(imageNamed: "Bird1")
        birdTexture1.filteringMode = SKTextureFilteringMode.Nearest
        var birdTexture2 = SKTexture(imageNamed: "Bird2")
        birdTexture2.filteringMode = SKTextureFilteringMode.Nearest
        
        var anim = SKAction.animateWithTextures([birdTexture1, birdTexture2], timePerFrame: 0.2)
        var flap = SKAction.repeatActionForever(anim)
        
        /* add bird texture to the view and give a start position */
        bird = SKSpriteNode(texture: birdTexture1)
        bird.position = CGPoint(x: self.frame.size.width / 2.8, y:CGRectGetMidY(self.frame))
        bird.runAction(flap)
        
        /* add physics params to the bird */
        bird.physicsBody = SKPhysicsBody(circleOfRadius: bird.size.height / 2.0)
        bird.physicsBody?.dynamic = true
        bird.physicsBody?.allowsRotation = false
        
        bird.physicsBody?.categoryBitMask = birdCategory
        bird.physicsBody?.collisionBitMask = worldCategory | pipeCategory
        bird.physicsBody?.contactTestBitMask = worldCategory | pipeCategory
        
        self.addChild(bird)
        
        /* add ground object to the view */
        var groundTexture = SKTexture(imageNamed: "Ground")
        groundTexture.filteringMode = SKTextureFilteringMode.Nearest
        
        /* how fast the ground should move < 0.01 is faster and > 0.01 is slower */
        /* pipes and ground move at the same speed; 0.08 is the value to change */
        var moveGroundSprite = SKAction.moveByX(-groundTexture.size().width, y: 0, duration: NSTimeInterval(0.008 * groundTexture.size().width))
        var resetGroundSprite = SKAction.moveByX(groundTexture.size().width, y: 0, duration: 0.0)
        var moveGroundSpritesForever = SKAction.repeatActionForever(SKAction.sequence([moveGroundSprite,resetGroundSprite]))
        
        /* fill screen with ground image */
        for var i:CGFloat = 0; i < 2 + self.frame.size.width / ( groundTexture.size().width); ++i {
            var sprite = SKSpriteNode(texture: groundTexture)
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2)
            sprite.runAction(moveGroundSpritesForever)
            moving.addChild(sprite)
        }
        
        /* dummy node for bird contact with the moving ground */
        var dummy = SKNode()
        dummy.position = CGPointMake(0, groundTexture.size().height / 2)
        dummy.physicsBody = SKPhysicsBody(rectangleOfSize: CGSizeMake(self.frame.size.width, groundTexture.size().height))
        dummy.physicsBody?.dynamic = false /* this shows the node a not moving component */
        dummy.physicsBody?.categoryBitMask = worldCategory;
        self.addChild(dummy)
        
        /* add skyline to the view */
        var skyTexture = SKTexture(imageNamed: "Skyline")
        skyTexture.filteringMode = SKTextureFilteringMode.Nearest
        
        /* move skyline slower than the ground 0.01(ground) vs 0.1(skyline) */
        var moveSkySprite = SKAction.moveByX(-skyTexture.size().width, y: 0, duration: NSTimeInterval(0.1 * skyTexture.size().width))
        var resetSkySprite = SKAction.moveByX(skyTexture.size().width, y: 0, duration: 0.0)
        var moveSkySpritesForever = SKAction.repeatActionForever(SKAction.sequence([moveSkySprite,resetSkySprite]))
        
        /* fill screen width with skyline just like ground */
        for var i:CGFloat = 0; i < 2.0 + self.frame.size.width / ( skyTexture.size().width); ++i {
            var sprite = SKSpriteNode(texture: skyTexture)
            sprite.zPosition = -20;
            sprite.position = CGPointMake(i * sprite.size.width, sprite.size.height / 2 + groundTexture.size().height);
            sprite.runAction(moveSkySpritesForever)
            moving.addChild(sprite)
        }
        
        /* add pipes to the view */
        pipeTexture1 = SKTexture(imageNamed: "Pipe1")
        pipeTexture1.filteringMode = SKTextureFilteringMode.Nearest
        pipeTexture2 = SKTexture(imageNamed: "Pipe2")
        pipeTexture2.filteringMode = SKTextureFilteringMode.Nearest
        
        /* determines how fast the pipes move; same as the ground */
        var distanceToMove = CGFloat(self.frame.size.width + 2 * pipeTexture1.size().width);
        var movePipes = SKAction.moveByX(-distanceToMove, y:0, duration:NSTimeInterval(0.008 * distanceToMove));
        var removePipes = SKAction.removeFromParent();
        moveAndRemovePipes = SKAction.sequence([movePipes, removePipes]);

        var spawn = SKAction.runBlock({() in self.spawnPipes()})
        var delay = SKAction.waitForDuration(NSTimeInterval(2.0)) /* changing this value increases the pipe spawns */
        var spawnThenDelay = SKAction.sequence([spawn, delay])
        var spawnThenDelayForever = SKAction.repeatActionForever(spawnThenDelay)
        self.runAction(spawnThenDelayForever)
        
        score = 0
        scoreLabelNode.fontName = "Helvetica-Bold"
        scoreLabelNode.position = CGPointMake( CGRectGetMidX( self.frame ), self.frame.size.height / 6 )
        //let screen = UIScreen.mainScreen().nativeBounds
        //scoreLabelNode.position = CGPointMake( screen.width - 20, screen.height / 4 )
        //println("X: \(screen.width - scoreLabelNode.frame.width) and Y: \(( screen.height - scoreLabelNode.frame.height ))")
        //println("\(screen.width)")
        scoreLabelNode.fontSize = 600
        scoreLabelNode.alpha = 0.4
        scoreLabelNode.zPosition = -30
        scoreLabelNode.text = "\(score)"
        self.addChild(scoreLabelNode)
        
        /* enable jet functionality upon double tap */
        /*let bSelector : Selector = "jet:"
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: bSelector)
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)*/
        
    }
    
    func spawnPipes() {
        var pipePair = SKNode()
        pipePair.position = CGPointMake( self.frame.size.width + pipeTexture1.size().width * 2, 0 );
        pipePair.zPosition = -10;
        
        var height = UInt32( self.frame.size.height / 3 )
        var y = arc4random() % height;
        
        var pipe1 = SKSpriteNode(texture: pipeTexture1)
        pipe1.position = CGPointMake(0.0, CGFloat(y))
        pipe1.physicsBody = SKPhysicsBody(rectangleOfSize: pipe1.size)
        pipe1.physicsBody?.dynamic = false
        pipe1.physicsBody?.categoryBitMask = pipeCategory;
        pipe1.physicsBody?.contactTestBitMask = birdCategory;
        pipePair.addChild(pipe1)
        
        var pipe2 = SKSpriteNode(texture: pipeTexture2)
        pipe2.position = CGPointMake(0.0, CGFloat(y) + pipe1.size.height + CGFloat(verticalPipeGap))
        pipe2.physicsBody = SKPhysicsBody(rectangleOfSize: pipe2.size)
        pipe2.physicsBody?.dynamic = false
        pipe2.physicsBody?.categoryBitMask = pipeCategory;
        pipe2.physicsBody?.contactTestBitMask = birdCategory;
        pipePair.addChild(pipe2)
        
        var contactNode = SKNode()
        contactNode.position = CGPointMake( pipe1.size.width + bird.size.width / 2, CGRectGetMidY( self.frame ) )
        contactNode.physicsBody = SKPhysicsBody(rectangleOfSize: CGSizeMake(pipe1.size.width, self.frame.size.height))
        contactNode.physicsBody?.dynamic = false
        contactNode.physicsBody?.categoryBitMask = scoreCategory
        contactNode.physicsBody?.contactTestBitMask = birdCategory
        pipePair.addChild(contactNode)
        
        pipePair.runAction(moveAndRemovePipes)
        
        pipes.addChild(pipePair)
    }
    
    func resetScene() {
        bird.position = CGPoint(x: self.frame.size.width / 2.8, y:CGRectGetMidY(self.frame))
        bird.physicsBody?.velocity = CGVectorMake(0, 0)
        bird.physicsBody?.collisionBitMask = worldCategory | pipeCategory;
        bird.speed = 1.0;
        bird.zRotation = 0.0;
        
        pipes.removeAllChildren()
        
        canRestart == false
        
        moving.speed = 1
        
        score = 0;
        scoreLabelNode.text = "\(score)"
        
    }
    
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        /* Called when a touch begins */
        if (moving.speed > 0) {
            bird.physicsBody?.velocity = CGVectorMake(0, 0)
            bird.physicsBody?.applyImpulse(CGVectorMake(0, 6))
        } else if (canRestart) {
            self.resetScene()
        }
    }
    
    func impulse() {
    
    }
    
    func didBeginContact(contact: SKPhysicsContact!) {
        
        if( moving.speed > 0 ) {
            
            if( ( contact.bodyA.categoryBitMask & scoreCategory ) == scoreCategory || ( contact.bodyB.categoryBitMask & scoreCategory ) == scoreCategory ) {
                
                score++;
                scoreLabelNode.text = "\(score)"
            } else {
                moving.speed = 0;
                
                bird.physicsBody?.collisionBitMask = worldCategory
                
                var rotateBird = SKAction.rotateByAngle(0.01, duration: 0.003)
                var stopBird = SKAction.runBlock({() in self.killBirdSpeed()})
                var birdSequence = SKAction.sequence([rotateBird, stopBird])
                bird.runAction(birdSequence)
                
                self.removeActionForKey("flash")
                var turnBackgroundRed = SKAction.runBlock({() in self.setBackgroundColorRed()})
                var wait = SKAction.waitForDuration(0.05)
                var turnBackgroundWhite = SKAction.runBlock({() in self.setBackgroundColorWhite()})
                var turnBackgroundSky = SKAction.runBlock({() in self.setBackgroundColorSky()})
                var sequenceOfActions = SKAction.sequence([turnBackgroundRed,wait,turnBackgroundWhite,wait, turnBackgroundSky])
                var repeatSequence = SKAction.repeatAction(sequenceOfActions, count: 4)
                var canRestartAction = SKAction.runBlock({() in self.letItRestart()})
                var groupOfActions = SKAction.group([repeatSequence, canRestartAction])
                self.runAction(groupOfActions, withKey: "flash")
            }
        }
    }
    
    func killBirdSpeed() {
        bird.speed = 0
    }
    
    func letItRestart() {
        canRestart = true
    }
    
    func setBackgroundColorRed() {
        self.backgroundColor = UIColor.redColor()
    }
    
    func setBackgroundColorWhite() {
        self.backgroundColor = UIColor.whiteColor()
    }
    
    func setBackgroundColorSky() {
        self.backgroundColor = SKColor(red:113.0/255.0, green:197.0/255.0, blue:207.0/255.0, alpha:1.0)
    }
    
    func clamp(min: CGFloat, max: CGFloat, value: CGFloat) -> CGFloat {
        if( value > max ) {
            return max
        } else if( value < min ) {
            return min
        } else {
            return value
        }
    }
   
    override func update(currentTime: CFTimeInterval) {
        /* Called before each frame is rendered */
        if (moving.speed > 0) {
            bird.zRotation = self.clamp( -1, max: 0.5, value: bird.physicsBody!.velocity.dy * ( bird.physicsBody!.velocity.dy < 0 ? 0.003 : 0.001))
        }
    }
    
}
