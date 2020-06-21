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
    
    // 对name进行观察
    [self.per ys_addObserver:self forKey:@"name" withCallbackOnMainthread:false andCallback:^(id  _Nonnull observedObject, NSString * _Nonnull observedKey, id  _Nonnull oldValue, id  _Nonnull newValue) {
        NSLog(@"%@, %@, %@, %@, %@", [NSThread currentThread], observedObject, observedKey, oldValue, newValue);
    }];
    
    // 对book进行观察
    [self.per ys_addObserver:self forKey:@"book" withCallbackOnMainthread:true andCallback:^(id  _Nonnull observedObject, NSString * _Nonnull observedKey, id  _Nonnull oldValue, id  _Nonnull newValue) {
        
    }];
    
    [self.per ys_removeObserver:self forKey:@"name"];
    [self.per ys_removeObserver:self forKey:@"book"];
    
}

- (void)dealloc
{
    // 结合key和观察者移除
    [self.per ys_removeObserver:self forKey:@"name"];
    [self.per ys_removeObserver:self forKey:@"book"];
    
    // 移除观察者的所有观察
    [self.per ys_removeObserver:self];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    self.per.name = @"小明";
    self.per.book = @"上下五千年";
}

@end
