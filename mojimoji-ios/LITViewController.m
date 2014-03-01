//
//  LITViewController.m
//  mojimoji-ios
//
//  Created by Takuma YOSHITANI on 2/21/14.
//  Copyright (c) 2014 Takuma YOSHITANI. All rights reserved.
//

#import "LITViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <CoreMotion/CoreMotion.h>
#import <AudioToolbox/AudioToolbox.h>

#import <Reachability/Reachability.h>
#import <AZSocketIO/AZSocketIO.h>
#import <FDStatusBarNotifierView/FDStatusBarNotifierView.h>

#import "UIColor+Hex.h"
#import "UIImage+Color.h"

#define HOST @"mojimoji.herokuapp.com"
//#define HOST @"192.168.11.2"
#define PORT @"80"

#define FREQ (60.0f)

#define kMotionCircleRadius (37.5)
#define kMotionCircleCenterX (160)
#define kMotionCircleCenterY (300)
#define kMotionCircleBorderWidth (1.0f)
#define kCenterPointRadius (2)
#define kMotionPointRadius (4)

#define kHpCircleRadius (100)
#define kHpCircleCenterX (160)
#define kHpCircleCenterY (300)

#define kHpBaseCircleRadius (100)
#define kHpBaseCircleCenterX (160)
#define kHpBaseCircleCenterY (300)

#define kThreshold (1e-4)

#define kTextFieldX (200)
#define kTextFieldY (170)
#define kTextFieldW (120)
#define kTextFieldH (30)

#define kButtonR (50)

#define kEnabledColor @"#2ecc71"
#define kDisabledColor @"#ecf0f1"
#define kNormalColor @"#aaaaaa"
#define kShieldingColor @"#3498db"
#define kChargingColor @"#e67e22"
#define kAttackableColor @"#e74c3c"
#define kAttackingColor @"c0392b"

@interface LITViewController ()

@property (nonatomic) CMMotionManager* motionManager;
@property (nonatomic, strong) AZSocketIO* socketIO;
@property (nonatomic) UIButton* connectBtn;

@property (nonatomic) double gx;
@property (nonatomic) double gy;
@property (nonatomic) double r;
@property (nonatomic) NSString* name;
@property (nonatomic) double hp;

@property (nonatomic) UIView* motionCircle;
@property (nonatomic) UIView* motionPoint;

@property (nonatomic) UIView* hpCircle;
@property (nonatomic) UIView* hpBaseCircle;

@property (nonatomic) UITextField* textField;

@end

@implementation LITViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.r = 20;
    self.hp = 100;
    __weak typeof(self) wself = self;
    
    self.textField = [[UITextField alloc] initWithFrame:CGRectMake(kTextFieldX, kTextFieldY, kTextFieldW, kTextFieldH)];
    [self.textField setClearButtonMode:UITextFieldViewModeWhileEditing];
    [self.textField setReturnKeyType:UIReturnKeySend];
//    [self.textField setText:self.name];
    [self.textField setDelegate:self];
    [self.textField setTextColor:[UIColor colorWithHex:kNormalColor]];
    [self.view addSubview:self.textField];
    
    // Set up motion manager
    self.motionManager = [[CMMotionManager alloc] init];
    if(self.motionManager.isDeviceMotionAvailable){
        self.motionManager.gyroUpdateInterval = 1.0f / FREQ;
        [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
            self.gx = motion.gravity.x;
            self.gy = motion.gravity.y;
            
            if(fabs(self.gx) < kThreshold){
                self.gx = 0;
            }
            if(fabs(self.gy) < kThreshold){
                self.gy = 0;
            }
            [self displayGravity];
            [self sendGravity];
        }];
    }
    
    // configure view
    self.hpBaseCircle = [[UIView alloc] initWithFrame:CGRectMake(kHpBaseCircleCenterX - kHpBaseCircleRadius, kHpBaseCircleCenterY - kHpBaseCircleRadius, kHpBaseCircleRadius*2, kHpBaseCircleRadius*2)];
    [self.hpBaseCircle.layer setCornerRadius:kHpBaseCircleRadius];
    [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kDisabledColor alpha:0.5].CGColor];
    
    self.hpCircle = [[UIView alloc] initWithFrame:CGRectMake(kHpCircleCenterX - kHpCircleRadius, kHpCircleCenterY - kHpCircleRadius, kHpCircleRadius*2, kHpCircleRadius*2)];
    [self.hpCircle.layer setCornerRadius:kHpCircleRadius];
    [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kDisabledColor].CGColor];
    
    [self.view addSubview:self.hpBaseCircle];
    [self.view addSubview:self.hpCircle];
    
    self.motionCircle = [[UIView alloc] initWithFrame:CGRectMake(kMotionCircleCenterX - kMotionCircleRadius, kMotionCircleCenterY - kMotionCircleRadius, kMotionCircleRadius*2, kMotionCircleRadius*2)];
    [self.motionCircle.layer setCornerRadius:kMotionCircleRadius];
//    [self.motionCircle.layer setBorderWidth:kMotionCircleBorderWidth];
//    [self.motionCircle.layer setBorderColor:[UIColor blackColor].CGColor];
    [self.motionCircle.layer setBackgroundColor:[UIColor colorWithHex:@"#ffffff"].CGColor];
    UIView *centerPoint = [[UIView alloc] initWithFrame:CGRectMake(kMotionCircleRadius, kMotionCircleRadius, kCenterPointRadius*2, kCenterPointRadius*2)];
    [centerPoint.layer setCornerRadius:kCenterPointRadius];
    [centerPoint.layer setBackgroundColor:[UIColor colorWithHex:@"#000000"].CGColor];
    [self.motionCircle addSubview:centerPoint];
    
    self.motionPoint = [[UIView alloc] initWithFrame:CGRectMake(kMotionCircleRadius, kMotionCircleRadius, kMotionPointRadius*2, kMotionPointRadius*2)];
    [self.motionPoint.layer setCornerRadius:kMotionPointRadius];
    [self.motionPoint.layer setBackgroundColor:[UIColor colorWithHex:@"#000000" alpha:0.5].CGColor];
    [self.motionCircle addSubview:self.motionPoint];
    
    [self.view addSubview:self.motionCircle];
    
    // Buttons
    UIButton* btn;

    btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"shield" forState:UIControlStateNormal];
    [btn setFrame:CGRectMake(30, 300, kButtonR*2, kButtonR*2)];
    [[btn layer] setCornerRadius:kButtonR];
    [btn setClipsToBounds:YES];
    [btn setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithHex:kShieldingColor alpha:0.8]]
                   forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(sendStartShielding) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(sendEndShielding) forControlEvents:UIControlEventTouchUpInside];
    [btn addTarget:self action:@selector(sendEndShielding) forControlEvents:UIControlEventTouchUpOutside];
    [self.view addSubview:btn];

    btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"charge" forState:UIControlStateNormal];
    [btn setFrame:CGRectMake(150, 350, kButtonR*2, kButtonR*2)];
    [[btn layer] setCornerRadius:kButtonR];
    [btn setClipsToBounds:YES];
    [btn setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithHex:kChargingColor alpha:0.8]]
                   forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(sendStartCharging) forControlEvents:UIControlEventTouchDown];
    [btn addTarget:self action:@selector(sendEndCharging) forControlEvents:UIControlEventTouchUpInside];
    [btn addTarget:self action:@selector(sendEndCharging) forControlEvents:UIControlEventTouchUpOutside];
    [self.view addSubview:btn];
    
    btn = [UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"attack" forState:UIControlStateNormal];
    [btn setFrame:CGRectMake(220, 280, kButtonR*2*0.8, kButtonR*2*0.8)];
    [[btn layer] setCornerRadius:kButtonR*0.8];
    [btn setClipsToBounds:YES];
    [btn setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithHex:kAttackableColor alpha:0.8]]
                   forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(sendAttack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    self.connectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.connectBtn setTitle:@"Tap here\nto\nreconnect" forState:UIControlStateNormal];
    [self.connectBtn.titleLabel setLineBreakMode:NSLineBreakByWordWrapping];
    [self.connectBtn.titleLabel setTextAlignment:NSTextAlignmentCenter];
    [self.connectBtn setTitleColor:[UIColor colorWithHex:@"#c0392b"] forState:UIControlStateNormal];
    [self.connectBtn setFrame:CGRectMake(kMotionCircleCenterX - kMotionCircleRadius, kMotionCircleCenterY - kMotionCircleRadius, kMotionCircleRadius*2, kMotionCircleRadius*2)];
    [[self.connectBtn layer] setCornerRadius:kMotionCircleRadius];
    [self.connectBtn setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithHex:@"#bdc3c7"]] forState:UIControlStateNormal];
    [self.connectBtn setClipsToBounds:YES];
    [self.connectBtn addTarget:self action:@selector(connect) forControlEvents:UIControlEventTouchUpInside];
    [self.connectBtn setHidden:YES];
    [self.view addSubview:self.connectBtn];
    
    // Set up Socket.IO client for obj-c
    // connect to server
    self.socketIO = [[AZSocketIO alloc] initWithHost:HOST andPort:PORT secure:NO];
    [self.socketIO setEventRecievedBlock:^(NSString *eventName, id data) {
        [wself onEvent:[eventName copy] jsonObject:[data copy]];
    }];
    
    [self.socketIO setReconnect:NO];
    
    [self connect];
    
    [self.socketIO setDisconnectedBlock:^{
        NSLog(@"Connection lost");
        [wself alertOnStatusBarWithMessage:@"Connection lost."];
        [wself disable];
    }];
    
    [[UILabel appearance] setFont:[UIFont fontWithName:@"Courier" size:17.0]];
    [[UITextField appearance] setFont:[UIFont fontWithName:@"Courier" size:17.0]];
    
    [self.connectBtn.titleLabel setFont:[UIFont fontWithName:@"Courier" size:10.0]];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.socketIO disconnect];
    [self.motionManager stopDeviceMotionUpdates];
    self.motionManager = nil;
}

- (void)alertOnStatusBarWithMessage:(NSString *)message
{
    FDStatusBarNotifierView *notifierView = [[FDStatusBarNotifierView alloc] initWithMessage:message];
//    notifierView.timeOnScreen = 3.0; // by default it's 2 seconds
    [notifierView showInWindow:self.view.window];
}

- (void)displayGravity
{
    CGRect frame = self.motionPoint.frame;
    frame.origin.x = kMotionCircleRadius + self.gx*kMotionCircleRadius;
    frame.origin.y = kMotionCircleRadius - self.gy*kMotionCircleRadius;
    [self.motionPoint setFrame:frame];
}

- (void)enable
{
    [self.connectBtn setEnabled:YES];
    [self.connectBtn setHidden:YES];
    [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kNormalColor alpha:0.5].CGColor];
    [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kNormalColor].CGColor];
}

- (void)disable
{
    [self.connectBtn setEnabled:YES];
    [self.connectBtn setHidden:NO];
    [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kDisabledColor alpha:0.5].CGColor];
    [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kDisabledColor].CGColor];
}

#pragma mark - communication with server
- (void)connect
{
    NSLog(@"connecting...");
    [self.connectBtn setEnabled:NO];
    [self.socketIO connectWithSuccess:^{
        NSLog(@"Success connecting!");
        [self alertOnStatusBarWithMessage:@"Successfully connecting!"];
        [self enable];
    } andFailure:^(NSError *error) {
        NSLog(@"Failure connecting. error: %@", error);
        [self alertOnStatusBarWithMessage:@"Connection failed."];
        [self disable];
    }];
}

- (void)onEvent:(NSString *)eventName jsonObject:(id)jsonObject
{
    NSArray* aData = jsonObject;
    NSDictionary* data = aData[0];
    if([eventName isEqualToString:@"init"]){
        NSLog(@"initializing with data: %@", data);
        self.name = data[@"name"];
        [self.textField setText:self.name];
    }else if([eventName isEqualToString:@"update"]){
//        NSLog(@"update: %@", data);
        NSDictionary* myData = data[@"clients"][self.socketIO.sessionId];
//        NSLog(@"%@", myData);
        double nhp = [(NSNumber *)myData[@"hp"] doubleValue];
        if(self.hp > nhp){
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        }
        self.hp = nhp;
        if(nhp < 0){
            [self.socketIO disconnect];
            [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kDisabledColor alpha:0.5].CGColor];
            [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kDisabledColor].CGColor];
            UIAlertView *alert =
            [[UIAlertView alloc] initWithTitle:@"Game over!" message:@""
                                      delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            nhp = 0;
        }
        double hpCircleRadius = kMotionCircleRadius + (kHpBaseCircleRadius - kMotionCircleRadius)*nhp/100;
        [self.hpCircle setFrame:CGRectMake(kHpCircleCenterX - hpCircleRadius, kHpCircleCenterY - hpCircleRadius, hpCircleRadius*2, hpCircleRadius*2)];
        [self.hpCircle.layer setCornerRadius:hpCircleRadius];
        
        if([(NSNumber *)myData[@"isShielding"] boolValue]){
            [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kShieldingColor alpha:0.5].CGColor];
            [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kShieldingColor].CGColor];
        }else if([(NSNumber *)myData[@"isAttackable"] boolValue]){
            [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kAttackableColor alpha:0.5].CGColor];
            [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kAttackableColor].CGColor];
        }else if([(NSNumber *)myData[@"isAttacking"] boolValue]){
            [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kAttackingColor alpha:0.5].CGColor];
            [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kAttackingColor].CGColor];
        }else if([(NSNumber *)myData[@"isCharging"] boolValue]){
            [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kChargingColor alpha:0.5].CGColor];
            [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kChargingColor].CGColor];
        }else{
            [self.hpBaseCircle.layer setBackgroundColor:[UIColor colorWithHex:kNormalColor alpha:0.5].CGColor];
            [self.hpCircle.layer setBackgroundColor:[UIColor colorWithHex:kNormalColor].CGColor];
        }
        
    }else{
        NSLog(@"eventName: %@, data: %@", eventName, data);
    }
}

- (void)sendRadius
{
    [self.socketIO emit:@"set r" args:@{@"r": [NSNumber numberWithDouble:self.r]} error:NULL];
}

- (void)sendGravity
{
    [self.socketIO emit:@"set gravity"
                   args:@{
                          @"gx": [NSNumber numberWithDouble:self.gx],
                          @"gy": [NSNumber numberWithDouble:self.gy],
                          }
                  error:NULL];
}

- (void)sendNameDidChange
{
    [self.socketIO emit:@"set name" args:@{@"name":self.name} error:NULL];
}

- (void)sendStartShielding
{
    [self.socketIO emit:@"start shielding" args:@{} error:NULL];
}

- (void)sendEndShielding
{
    [self.socketIO emit:@"end shielding" args:@{} error:NULL];
}

- (void)sendStartCharging
{
    [self.socketIO emit:@"start charging" args:@{} error:NULL];
}

- (void)sendEndCharging
{
    [self.socketIO emit:@"end charging" args:@{} error:NULL];
}

- (void)sendAttack
{
    [self.socketIO emit:@"attack" args:@{} error:NULL];
}

#pragma mark - UITextField delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    self.name = textField.text;
    [textField resignFirstResponder];
    [self sendNameDidChange];
    return YES;
}

@end
