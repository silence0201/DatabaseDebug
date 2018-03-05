# DatabaseDebug
一个简易可以通过Web调试工具,基于GCDWebServer和FMDB

## 安装
#### 1. 添加引用
依赖于GCDWebServer(3.X)和FMDB(2.X)
#### 2. 导入文件
下载项目后,将项目下`DatabaseDebug`添加到项目中

## 使用
1. 导入头文件

    ```objective-c
	#import "SIPageManager.h"
	```
2. 启动服务器(支持自定义路径,默认使用Caches和Documents)

    ```objective-c
	[[DatabaseWebServer shared] startServerOnPort:9002];
	```

3. 调试(注意查看日志)
    会有提示:`请使用浏览器打开http://XX:XX`

## DatabaseDebug
DatabaseDebug is available under the MIT license. See the LICENSE file for more info.
