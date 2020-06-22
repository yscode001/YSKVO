# YSKVO
自定义KVO实现

## 环境
Objective-C   iOS11

### 与苹果提供的KVO相比：

#### 优势
1、移除KVO不再是必须步骤，不移除也可以，因为提供的功能包含了自动移除的功能
2、在监听回调的block里面，可以设置回调是否在主线程执行
3、一个监听一个回调，简单清晰，相比系统自带的所有回调都在observerValueForKeypath中执行，更加清晰
4、放心使用，此提供的功能是线程安全的

#### 劣势
1、只提供监听key，未提供keypath

### 使用
1、pod 'YSKVO'
2、pod install
3、import <YSKVO/YSKVO.h>

### 添加观察者

```
// 对per的name属性进行观察
[self.per ys_addObserver:self forKey:@"name" withCallbackOnMainthread:false andCallback:^(id  _Nonnull observedObject, NSString * _Nonnull observedKey, id  _Nonnull oldValue, id  _Nonnull newValue) {
    NSLog(@"%@, %@, %@, %@, %@", [NSThread currentThread], observedObject, observedKey, oldValue, newValue);
}];
```

### 移除观察者

```
// 移除方法非必须，因为在调用kvo的block前，会自动把observer为nil的移除
// 提供移除方法，主要是为了在某些场景下，需要手动进行移除

// 结合key和观察者移除
[self.per ys_removeObserver:self forKey:@"name"];

// 移除观察者的所有观察
[self.per ys_removeObserver:self];
```
