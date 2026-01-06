# Gradle 下载错误修复

## 错误信息

```
Exception in thread "main" java.util.zip.ZipException: zip END header not found
Error: Gradle task assembleDebug failed with exit code 1
```

## 原因

Gradle wrapper 下载的 zip 文件损坏或不完整。这通常发生在：
1. 网络中断导致下载不完整
2. 缓存文件损坏
3. 首次下载新版本 Gradle

## 解决方案

### 方案 1：清理 Gradle 缓存（推荐）

```bash
# 1. 删除损坏的 Gradle 缓存
rm -rf ~/.gradle/wrapper/dists/gradle-8.7-all
rm -rf ~/.gradle/wrapper/dists/gradle-8.6-all

# 2. 清理 Flutter 构建缓存
cd example
flutter clean

# 3. 重新获取依赖
flutter pub get

# 4. 重新构建（首次会下载 Gradle，需要等待 5-10 分钟）
flutter build apk --debug
```

### 方案 2：使用稳定版本 Gradle 8.6

如果 Gradle 8.7 下载有问题，可以使用 8.6（已经在代码中更新）：

**文件**: `example/android/gradle/wrapper/gradle-wrapper.properties`

```properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-all.zip
```

### 方案 3：手动下载 Gradle

如果自动下载一直失败，可以手动下载：

```bash
# 1. 下载 Gradle 8.6
wget https://services.gradle.org/distributions/gradle-8.6-all.zip

# 或使用浏览器下载：
# https://services.gradle.org/distributions/gradle-8.6-all.zip

# 2. 创建 Gradle 缓存目录
mkdir -p ~/.gradle/wrapper/dists/gradle-8.6-all

# 3. 移动下载的文件到缓存目录
# 注意：需要创建一个随机 hash 目录，例如：
mkdir -p ~/.gradle/wrapper/dists/gradle-8.6-all/abc123
mv gradle-8.6-all.zip ~/.gradle/wrapper/dists/gradle-8.6-all/abc123/

# 4. 重新构建
cd example
flutter build apk --debug
```

### 方案 4：使用国内镜像（中国用户）

如果在中国，可以使用阿里云镜像加速下载：

**文件**: `example/android/gradle/wrapper/gradle-wrapper.properties`

```properties
# 使用阿里云镜像
distributionUrl=https\://mirrors.aliyun.com/macports/distfiles/gradle/gradle-8.6-all.zip
```

或者在 `example/android/build.gradle` 中添加：

```groovy
allprojects {
    repositories {
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        google()
        mavenCentral()
    }
}
```

## 当前配置

已经将 Gradle 版本从 8.7 改为 8.6，这个版本更稳定：

```properties
# example/android/gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-all.zip
```

## 首次构建说明

首次构建会下载 Gradle（约 100MB），需要：
- **时间**: 5-10 分钟（取决于网络速度）
- **网络**: 需要稳定的网络连接
- **耐心**: 不要中断下载过程

### 构建进度

```bash
# 运行构建命令
cd example
flutter build apk --debug

# 你会看到类似的输出：
# Downloading https://services.gradle.org/distributions/gradle-8.6-all.zip
# .........10%.........20%.........30%........
```

## 验证构建

构建成功后，你会看到：

```
✓ Built build/app/outputs/flutter-apk/app-debug.apk (XX.XMB)
```

## 后续构建

首次构建成功后，后续构建会很快，因为 Gradle 已经缓存了。

## 故障排除

### 如果构建仍然失败

1. **检查网络连接**
   ```bash
   ping services.gradle.org
   ```

2. **检查磁盘空间**
   ```bash
   df -h
   ```
   确保有至少 2GB 可用空间

3. **检查 Gradle 缓存**
   ```bash
   ls -la ~/.gradle/wrapper/dists/
   ```

4. **完全清理并重试**
   ```bash
   # 删除所有 Gradle 缓存
   rm -rf ~/.gradle/caches
   rm -rf ~/.gradle/wrapper
   
   # 清理项目
   cd example
   flutter clean
   rm -rf android/.gradle
   rm -rf android/build
   
   # 重新构建
   flutter pub get
   flutter build apk --debug
   ```

## 使用 Android Studio 构建

如果命令行构建有问题，可以使用 Android Studio：

1. 打开 Android Studio
2. 打开项目：`example/android`
3. 等待 Gradle 同步完成
4. 点击 Build > Build Bundle(s) / APK(s) > Build APK(s)

Android Studio 会自动处理 Gradle 下载。

## 参考

- [Gradle Wrapper 文档](https://docs.gradle.org/current/userguide/gradle_wrapper.html)
- [Flutter Android 构建文档](https://docs.flutter.dev/deployment/android)
