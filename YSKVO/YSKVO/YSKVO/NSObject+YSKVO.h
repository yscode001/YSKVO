//
//  NSObject+YSKVO.h
//  YSKVO
//
//  Created by yaoshuai on 2020/6/21.
//  Copyright © 2020 YS. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 属性变化后执行的block
/// @param observedObject 被观察的对象
/// @param observedKey 被观察的属性Key
/// @param oldValue 被观察属性的旧值
/// @param newValue 被观察属性的新值
typedef void(^YSKVOObservingBlock)(id observedObject, NSString * observedKey, id oldValue, id newValue);

@interface NSObject (YSKVO)

/// 添加观察者，如果是第一次被观察，isa指向生成的kvo子类
/// @param observer 需要添加的观察者
/// @param key 被观察属性Key
/// @param callbackIsOnMainthread 回调是否在主线程上
/// @param callback 被观察属性变化后执行的block
- (void)ys_addObserver:(NSObject *)observer forKey:(NSString *)key withCallbackOnMainthread:(BOOL)callbackIsOnMainthread andCallback:(YSKVOObservingBlock)callback;

/// 移除观察者的某个key，当所有观察者全部移除后，isa指回原来的类
/// @param observer 需要移除的观察者
/// @param key 被观察属性Key
- (void)ys_removeObserver:(NSObject *)observer forKey:(NSString *)key;

/// 移除观察者的所有key，当所有观察者全部移除后，isa指回原来的类
- (void)ys_removeObserver:(NSObject *)observer;
 
@end

NS_ASSUME_NONNULL_END
