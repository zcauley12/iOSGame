//
//  GameScene.swift
//  MobileGame
//
//  Created by Zachary Cauley on 12/5/19.
//  Copyright © 2019 Zach. All rights reserved.
//

import SpriteKit
import GameplayKit

func +(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

func -(left: CGPoint, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

func *(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x * scalar, y: point.y * scalar)
}

func /(point: CGPoint, scalar: CGFloat) -> CGPoint {
  return CGPoint(x: point.x / scalar, y: point.y / scalar)
}

#if !(arch(x86_64) || arch(arm64))
  func sqrt(a: CGFloat) -> CGFloat {
    return CGFloat(sqrtf(Float(a)))
  }
#endif

extension CGPoint {
  func length() -> CGFloat {
    return sqrt(x*x + y*y)
  }
  
  func normalized() -> CGPoint {
    return self / length()
  }
}

struct PhysicsCategory {
  static let none      : UInt32 = 0 //0
  static let all       : UInt32 = UInt32.max
  static let monster   : UInt32 = 0b1 //1
  static let projectile: UInt32 = 0b10 //2
  static let player    : UInt32 = 0b11 //3
}


class GameScene: SKScene {
    
    //creating player and background sprites
    let player = SKSpriteNode(imageNamed: "player")
    let background = SKSpriteNode(imageNamed: "space")
    var monster = SKSpriteNode(imageNamed: "enemy")
    static var scoreLabel: SKLabelNode!
    let gameOverNode = SKView()

    static var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    override func didMove(to view: SKView) {
        //setting backgound behind all other sprites
        background.zPosition = -1
        //setting position of background
        background.position = CGPoint(x: frame.size.width / 2, y: frame.size.height / 2)
        //adding background to scene
        addChild(background)
        
        //setting position of player to far left middle of device
        player.position = CGPoint(x: size.width * 0.1, y: size.height * 0.5)
        //scaling player down to fit
        player.setScale(0.2)
        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: player.size.width, height: frame.size.height))
        player.physicsBody?.isDynamic = true
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.monster
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.affectedByGravity = false
        //adding player to scene
        addChild(player)
        
        
        //physicsWorld.gravity = .init(dx: 0.0, dy: -9.8)
        physicsWorld.gravity = .init(dx: 0.0, dy: -60)
        physicsWorld.contactDelegate = self
        run(SKAction.repeatForever(
            SKAction.sequence([SKAction.run(addMonster), SKAction.wait(forDuration: 1.0)])))
        
        GameScene.scoreLabel = SKLabelNode(fontNamed: "Chalkduster")
        GameScene.scoreLabel.fontColor = .white
        GameScene.scoreLabel.text = "Score: 0"
        GameScene.scoreLabel.horizontalAlignmentMode = .right
        GameScene.scoreLabel.position = CGPoint(x: size.width * 0.9, y: size.height * 0.9)
        addChild(GameScene.scoreLabel)
    }

    func random() -> CGFloat {
        return CGFloat(Float(arc4random()) / 4294967296)
    }
    
    func random(min: CGFloat, max: CGFloat) -> CGFloat {
        return random() * (max - min) + min
    }
    
    func addMonster() {
        monster = SKSpriteNode(imageNamed: "enemy")
        monster.physicsBody = SKPhysicsBody(rectangleOf: monster.size)
        monster.physicsBody?.isDynamic = true
        monster.physicsBody?.categoryBitMask = PhysicsCategory.monster
        monster.physicsBody?.contactTestBitMask = PhysicsCategory.projectile
        monster.physicsBody?.collisionBitMask = PhysicsCategory.none
        monster.physicsBody?.affectedByGravity = false
        
        monster.setScale(0.13)
        
        let actualY = random(min: monster.size.height/2, max: size.height - monster.size.height/2)
        
        monster.position = CGPoint(x: size.width + monster.size.width/2, y: actualY)
        
        addChild(monster)
        
        let actualDuration = random(min: CGFloat(2.0), max: CGFloat(4.0))
        
        let actionMove = SKAction.move(to: CGPoint(x: -monster.size.width/2, y: actualY), duration: TimeInterval(actualDuration))
        
        let actionMoveDone = SKAction.removeFromParent()
        
        monster.run(SKAction.sequence([actionMove, actionMoveDone]))
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
      //Choose one of the touches to work with
      guard let touch = touches.first else {
        return
      }
      let touchLocation = touch.location(in: self)
      
      //Set up initial location of projectile
      let projectile = SKSpriteNode(imageNamed: "projectile")
        
        projectile.setScale(0.07)
        
      projectile.position = player.position
        projectile.physicsBody = SKPhysicsBody(circleOfRadius: projectile.size.width/2)
        projectile.physicsBody?.isDynamic = true
        projectile.physicsBody?.categoryBitMask = PhysicsCategory.projectile
        projectile.physicsBody?.contactTestBitMask = PhysicsCategory.monster
        projectile.physicsBody?.collisionBitMask = PhysicsCategory.none
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        projectile.physicsBody?.affectedByGravity = false

      
      //Determine offset of location to projectile
      let offset = touchLocation - projectile.position
      
      //Stop out if you are shooting down or backwards
      if offset.x < 0 { return }
      
      //OK to add now
      addChild(projectile)
      
      //Get the direction of where to shoot
      let direction = offset.normalized()
      
      //Make it shoot far enough to be guaranteed off screen
      let shootAmount = direction * 1000
      
      //Add the shoot amount to the current position
      let realDest = shootAmount + projectile.position
      
      //Create the actions
      let actionMove = SKAction.move(to: realDest, duration: 2.0)
      let actionMoveDone = SKAction.removeFromParent()
      projectile.run(SKAction.sequence([actionMove, actionMoveDone]))
    }

    func projectileCollidedWithMonster(projectile: SKSpriteNode, monster: SKSpriteNode)
    {
        GameScene.score += 1
        projectile.removeFromParent()
        monster.physicsBody?.categoryBitMask = PhysicsCategory.none
        monster.physicsBody?.contactTestBitMask = PhysicsCategory.none
        monster.physicsBody?.collisionBitMask = PhysicsCategory.none
        let stop = SKAction.move(to: CGPoint(x: 0, y: -15), duration: TimeInterval(10))
        let done = SKAction.removeFromParent()
        monster.run(SKAction.sequence([stop, done]))
        monster.physicsBody?.affectedByGravity = true
    }
    
    func monsterCollidedWithPlayer(monster: SKSpriteNode, player: SKSpriteNode)
    {
        displayGameOver()
        //scene?.view?.isPaused = true
        //displayGameOver()
    }
}

extension GameScene: SKPhysicsContactDelegate
{
    /*func didBegin(_ contact: SKPhysicsContact) {
      // 1
      var firstBody: SKPhysicsBody
      var secondBody: SKPhysicsBody
      if contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask {
        firstBody = contact.bodyA
        secondBody = contact.bodyB
      } else {
        firstBody = contact.bodyB
        secondBody = contact.bodyA
      }
     
      // 2
      if ((firstBody.categoryBitMask & PhysicsCategory.monster != 0) && (secondBody.categoryBitMask & PhysicsCategory.projectile != 0)) {
        if let monster = firstBody.node as? SKSpriteNode, let projectile = secondBody.node as? SKSpriteNode {
          projectileCollidedWithMonster(projectile: projectile, monster: monster)
        }
      }
    }*/
    
    func didBegin(_ contact: SKPhysicsContact) {
      // 1
      var firstBody: SKPhysicsBody
      var secondBody: SKPhysicsBody
      if contact.bodyA.categoryBitMask == 1 && contact.bodyB.categoryBitMask == 2 {
        firstBody = contact.bodyA
        secondBody = contact.bodyB
      } else if contact.bodyA.categoryBitMask == 2 && contact.bodyB.categoryBitMask == 1{
        firstBody = contact.bodyB
        secondBody = contact.bodyA
      }
      else if contact.bodyA.categoryBitMask == 1 && contact.bodyB.categoryBitMask == 3{
        firstBody = contact.bodyA
        secondBody = contact.bodyB
        }
      else{
        firstBody = contact.bodyB
        secondBody = contact.bodyA
        }
     
      // 2
      if ((firstBody.categoryBitMask == 1) && (secondBody.categoryBitMask == 2)) {
        if let monster = firstBody.node as? SKSpriteNode, let projectile = secondBody.node as? SKSpriteNode {
          projectileCollidedWithMonster(projectile: projectile, monster: monster)
        }
      }
        
      if ((firstBody.categoryBitMask == 1) && (secondBody.categoryBitMask == 3)) {
          if let monster = firstBody.node as? SKSpriteNode, let player = secondBody.node as? SKSpriteNode {
          monsterCollidedWithPlayer(monster: monster, player: player)
          }
      }
    }
    
    func displayGameOver() {
        let gameOverScene = GameOverScene(size: size)
        gameOverScene.scaleMode = scaleMode

        let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
        view?.presentScene(gameOverScene, transition: reveal)
    }
}

class GameOverScene: SKScene {

   var notificationLabel = SKLabelNode(text: "Game Over")
    var notificationLabelScore = SKLabelNode(text: "Score: \(GameScene.score)")

    override init(size: CGSize) {
        super.init(size: size)

        self.backgroundColor = SKColor.darkGray

        addChild(notificationLabel)
        addChild(notificationLabelScore)
        notificationLabel.fontSize = 32.0
        notificationLabel.color = SKColor.white
        notificationLabel.fontName = "Thonburi-Bold"
        notificationLabel.position = CGPoint(x: size.width / 2, y: size.height / 2)
        
        notificationLabelScore.fontSize = 32.0
        notificationLabelScore.color = SKColor.white
        notificationLabelScore.fontName = "Thonburi-Bold"
        notificationLabelScore.position = CGPoint(x: size.width / 2, y: (size.height / 2) - 50)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

   override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        GameScene.score = 0
        let gameScene = GameScene(size: size)
        gameScene.scaleMode = scaleMode

        let reveal = SKTransition.flipHorizontal(withDuration: 0.5)
        view?.presentScene(gameScene, transition: reveal)
    }
}
