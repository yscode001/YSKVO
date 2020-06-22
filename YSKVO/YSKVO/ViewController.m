//
//  ViewController.m
//  YSKVO
//
//  Created by yaoshuai on 2020/6/21.
//  Copyright © 2020 YS. All rights reserved.
//

#import "ViewController.h"
#import "Person.h"
#import "YSKVO.h"

@interface ViewController ()

@property(nonatomic, strong) Person *per;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.per = Person.new;
    
    // 对per的name属性进行观察
    [self.per ys_addObserver:self forKey:@"name" withCallbackOnMainthread:false andCallback:^(id  _Nonnull observedObject, NSString * _Nonnull observedKey, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"%@, %@, %@, %@, %@", [NSThread currentThread], observedObject, observedKey, oldValue, newValue);
    }];
}

- (void)dealloc
{
    // 移除方法非必须，因为在调用kvo的block前，会自动把observer为nil的移除
    // 提供移除方法，主要是为了在某些场景下，需要手动进行移除
    
    // 结合key和观察者移除
    [self.per ys_removeObserver:self forKey:@"name"];
    
    // 移除观察者的所有观察
    [self.per ys_removeObserver:self];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    self.per.name = @"小明";
}

@end
