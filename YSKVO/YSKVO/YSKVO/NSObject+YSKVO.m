//
//  NSObject+YSKVO.m
//  YSKVO
//
//  Created by yaoshuai on 2020/6/21.
//  Copyright © 2020 YS. All rights reserved.
//

#import "NSObject+YSKVO.h"
#import <objc/message.h>

static NSString * const YSKVOClassPrefix = @"YSKVONotifying_";
static NSString * const YSKVOObservations = @"YSKVOObservations";

#pragma mark - 观察对象

@interface YSKVOObservation : NSObject

/// 观察者
@property (nonatomic, weak) NSObject *observer;

/// 被观察属性Key
@property (nonatomic, copy) NSString *key;

/// 回调的线程是否是主线程
@property (nonatomic, assign) BOOL callbackOnMainthread;

/// 被观察属性变化后的回调block
@property (nonatomic, copy) YSKVOObservingBlock block;

@end

@implementation YSKVOObservation

/// 自定义构造函数
/// @param observer 观察者
/// @param key 被观察属性Key
/// @param block 被观察属性变化后的回调block
- (instancetype)initWithObserver:(NSObject *)observer key:(NSString *)key callbackOnMainthread:(BOOL)cbOnMainthread block:(YSKVOObservingBlock)block {
    if (self = [super init]){
        self.observer = observer;
        self.key = key;
        self.callbackOnMainthread = cbOnMainthread;
        self.block = block;
    }
    return self;
}

@end

#pragma mark - NSObject的自定义KVO分类的实现

@implementation NSObject (YSKVO)

#pragma mark - 辅助方法

/// 当前对象是否包含selector方法
- (BOOL)yskvo_hasSelector:(SEL)selector {
    Class clazz = object_getClass(self);
    unsigned int methodCount = 0;
    
    // 获取方法列表
    Method *methodList = class_copyMethodList(clazz, &methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        SEL thisSelector = method_getName(methodList[i]);
        if (thisSelector == selector) {
            free(methodList);
            return YES;
        }
    }
    
    free(methodList);
    return NO;
}

/// 根据key获取标准的setterName
- (NSString * _Nullable)yskvo_getSetterName:(NSString *)key {
    if (key.length <= 0) {
        return nil;
    }
    
    // 第一个字母大写
    NSString *firstStr = [[key substringToIndex: 1] uppercaseString];
    // 第二个字母到最后
    NSString *remainingStr = [key substringFromIndex: 1];
    // 返回拼接成的setter
    return [NSString stringWithFormat:@"set%@%@:", firstStr, remainingStr];
}

/// 根据标准的setterName获取标准的getterName
- (NSString * _Nullable)yskvo_getGetterName:(NSString *)setterName {
    if (setterName.length < 4 || ![setterName hasPrefix:@"set"] || ![setterName hasSuffix:@":"]) {
        return nil;
    }
    // 先截掉set，获取后面属性字符，因为setter最后是冒号，所以length应减4
    NSRange range = NSMakeRange(3, setterName.length - 4);
    NSString *key = [setterName substringWithRange: range];
    
    // 把第一个字符换成小写
    NSString *firstStr = [[key substringToIndex: 1] lowercaseString];
    return [key stringByReplacingCharactersInRange: NSMakeRange(0, 1) withString: firstStr];
}

/// 获取当前类的父类
static Class yskvo_getSuperclass(id self, SEL _cmd) {
    return class_getSuperclass(object_getClass(self));
}

/// 生成kvo子类，注意加锁
- (Class)yskvo_createKVOChildClassWithOriginalClassName:(NSString *)originalClazzName {
    // 拼接kvo子类并生成
    NSString *kvoClazzName = [NSString stringWithFormat:@"%@%@", YSKVOClassPrefix, originalClazzName];
    Class kvoClazz = NSClassFromString(kvoClazzName);
    
    // 如果已经存在则返回
    if (kvoClazz) {
        return kvoClazz;
    }
    
    // 如果不存在，则传一个父类，子类类名，然后额外的空间（通常为 0），它返回给你一个子类
    // 同步锁，保证只创建一次
    @synchronized(self) {
        // 如果已经存在则返回
        Class kvoClazz2 = NSClassFromString(kvoClazzName);
        if (kvoClazz2) {
            return kvoClazz2;
        }
        
        Class originalClazz = object_getClass(self);
        kvoClazz = objc_allocateClassPair(originalClazz, kvoClazzName.UTF8String, 0);
        
        // 重写class方法，隐藏这个新的子类
        Method originalClazzMethod = class_getInstanceMethod(originalClazz, @selector(class));
        const char *originalTypes = method_getTypeEncoding(originalClazzMethod);
        class_addMethod(kvoClazz, @selector(class), (IMP)yskvo_getSuperclass, originalTypes);
        
        // 注册到runtime告诉runtime这个类的存在
        objc_registerClassPair(kvoClazz);
        
        return kvoClazz;
    }
}

/// 在setter实质调用之前，如果observer释放了，自动把观察者移除，如果没有观察者了，把isa指回原类，相当于全部移除观察者了。返回值表示是否还有观察者
- (BOOL)yskvo_autoRemoveObserverWhenItisNil_beforeSetter{
    // 获取所有观察者组合
    NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(YSKVOObservations));
    
    // 移除观察者
    NSMutableArray *deleteArrray = [NSMutableArray array];
    for (YSKVOObservation * observation in observations) {
        if (!observation.observer) {
            [deleteArrray addObject:observation];
        }
    }
    [observations removeObjectsInArray:deleteArrray];
    
    // 在移除所有观察者之后，让对象的isa指针重新指向它原本的类
    if (observations && observations.count == 0) {
        // 获取当前类的name
        Class clazz = object_getClass(self);
        NSString * clazzName = NSStringFromClass(clazz);
        
        // 如果当前类是kvo子类
        if ([clazzName hasPrefix:YSKVOClassPrefix]) {
            // 获取对象原本的类
            clazz = NSClassFromString([clazzName substringFromIndex:YSKVOClassPrefix.length]);
            // 让isa指向原本的类
            object_setClass(self, clazz);
        }
    }
    
    return observations.count > 0;
}

/// 子类实现KVO的setter方法，在setter方法里面进行回调，注意加锁
static void ys_kvoSetter(id self, SEL _cmd, id newValue) {
    // 根据setter获取getter，_cmd代表本方法的名称
    NSString * setterName = NSStringFromSelector(_cmd);
    NSString * getterName = [self yskvo_getGetterName:setterName];
    if (!getterName) {
        NSLog(@"YSKVO无效，因为key没有对应的getter方法");
        return;
    }
    
    BOOL hasObserver = [self yskvo_autoRemoveObserverWhenItisNil_beforeSetter];
    if (!hasObserver){
        NSLog(@"YSKVO自动移除，因为observer被全部自动释放了");
        return;
    }
    
    @synchronized(self) {
        // 根据key获取对应的旧值
        id oldValue = [self valueForKey: getterName];
        
        // 构造objc_super的结构体
        struct objc_super superclazz = {
            .receiver = self,
            .super_class = class_getSuperclass(object_getClass(self)),
        };
        
        // 对objc_msgSendSuper进行类型转换，解决编译器报错的问题
        void (*objc_msgSendSuperCasted)(void *, SEL, id) = (void *)objc_msgSendSuper;
        
        // id objc_msgSendSuper(struct objc_super *super, SEL op, ...) ,传入结构体、方法名称，和参数等
        objc_msgSendSuperCasted(&superclazz, _cmd, newValue);
        
        // 调用之前传入的 block
        NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(YSKVOObservations));
        for (YSKVOObservation * observation in observations) {
            if ([observation.key isEqualToString:getterName]) {
                if (observation.callbackOnMainthread){
                    dispatch_async(dispatch_get_main_queue(), ^{
                        observation.block(self, getterName, oldValue, newValue);
                    });
                } else{
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                        observation.block(self, getterName, oldValue, newValue);
                    });
                }
            }
        }
    }
}

#pragma mark - 添加观察者

/// 添加观察者，如果是第一次被观察，isa指向生成的kvo子类
- (void)ys_addObserver:(NSObject *)observer forKey:(NSString *)key withCallbackOnMainthread:(BOOL)callbackIsOnMainthread andCallback:(YSKVOObservingBlock)callback {
    // 检查对象的类有没有相应的setter方法
    SEL setterSelector = NSSelectorFromString([self yskvo_getSetterName:key]);
    // 因为重写了class，所以[self class]获取的一直是父类
    Method setterMethod = class_getInstanceMethod([self class], setterSelector);
    if (!setterMethod) {
        NSLog(@"YSKVO无效，因为key没有对应的setter方法");
        return;
    }
    
    // 获取当前类的name
    Class clazz = object_getClass(self);
    NSString *clazzName = NSStringFromClass(clazz);
    
    // 如果当前类不是kvo子类（如果添加了多次观察者，kvo子类在第一次添加观察者的时候就创建了）
    if (![clazzName hasPrefix:YSKVOClassPrefix]) {
        // 生成kvo子类
        clazz = [self yskvo_createKVOChildClassWithOriginalClassName:clazzName];
        // 让isa指向kvo子类
        object_setClass(self, clazz);
    }
    
    // 如果kvo子类没有对应的setter方法，则添加（同一个key可能会被添加多次）
    if (![self yskvo_hasSelector:setterSelector]) {
        const char * types = method_getTypeEncoding(setterMethod);
        class_addMethod(clazz, setterSelector, (IMP)ys_kvoSetter, types);
    }
    
    // 创建观察者组合
    YSKVOObservation * observation = [[YSKVOObservation alloc] initWithObserver:observer key:key callbackOnMainthread:callbackIsOnMainthread block:callback];
    // 获取所有观察者组合
    NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(YSKVOObservations));
    if (!observations) {
        observations = [NSMutableArray array];
        // 添加关联所有观察者组合
        objc_setAssociatedObject(self, (__bridge const void *)(YSKVOObservations), observations, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observations addObject:observation];
}

#pragma mark - 移除观察者

/// 移除观察者的某个key，当所有观察者全部移除后，isa指回原来的类
- (void)ys_removeObserver:(NSObject *)observer forKey:(NSString *)key {
    // 获取所有观察者组合
    NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(YSKVOObservations));
    
    // 根据key移除观察者组合
    NSMutableArray *deleteArrray = [NSMutableArray array];
    for (YSKVOObservation * observation in observations) {
        if (observation.observer == observer && [observation.key isEqual:key]) {
            [deleteArrray addObject:observation];
        }
    }
    [observations removeObjectsInArray:deleteArrray];
    
    // 在移除所有观察者之后，让对象的isa指针重新指向它原本的类
    if (observations && observations.count == 0) {
        // 获取当前类的name
        Class clazz = object_getClass(self);
        NSString * clazzName = NSStringFromClass(clazz);
        
        // 如果当前类是kvo子类
        if ([clazzName hasPrefix:YSKVOClassPrefix]) {
            // 获取对象原本的类
            clazz = NSClassFromString([clazzName substringFromIndex:YSKVOClassPrefix.length]);
            // 让isa指向原本的类
            object_setClass(self, clazz);
        }
    }
}

/// 移除观察者的所有key，当所有观察者全部移除后，isa指回原来的类
- (void)ys_removeObserver:(NSObject *)observer{
    // 获取所有观察者组合
    NSMutableArray * observations = objc_getAssociatedObject(self, (__bridge const void *)(YSKVOObservations));
    
    // 移除观察者
    NSMutableArray *deleteArrray = [NSMutableArray array];
    for (YSKVOObservation * observation in observations) {
        if (observation.observer == observer) {
            [deleteArrray addObject:observation];
        }
    }
    [observations removeObjectsInArray:deleteArrray];
    
    // 在移除所有观察者之后，让对象的isa指针重新指向它原本的类
    if (observations && observations.count == 0) {
        // 获取当前类的name
        Class clazz = object_getClass(self);
        NSString * clazzName = NSStringFromClass(clazz);
        
        // 如果当前类是kvo子类
        if ([clazzName hasPrefix:YSKVOClassPrefix]) {
            // 获取对象原本的类
            clazz = NSClassFromString([clazzName substringFromIndex:YSKVOClassPrefix.length]);
            // 让isa指向原本的类
            object_setClass(self, clazz);
        }
    }
}

@end
