# Gradle 中国镜像配置完成

## 已完成的操作

### 1. ✅ 下载 Gradle 8.6
使用腾讯云镜像成功下载 Gradle 8.6（210MB）：
```bash
curl -L -o /tmp/gradle-8.6-all.zip https://mirrors.cloud.tencent.com/gradle/gradle-8.6-all.zip
```

### 2. ✅ 安装到正确位置
```bash
~/.gradle/wrapper/dists/gradle-8.6-all/3mbtmo166bl6vumsh5k2lkq5h/gradle-8.6-all.zip
```

### 3. ✅ 更新配置使用国内镜像
**文件**: `example/android/gradle/wrapper/gradle-wrapper.properties`
```properties
distributionUrl=https\://mirrors.cloud.tencent.com/gradle/gradle-8.6-all.zip
```

### 4. ✅ 构建正在进行中
Gradle daemon 已启动，正在编译项目。

## 当前状态

构建正在后台运行，这是正常的。首次构建需要：
- 下载 Android SDK 组件
- 下载 Maven 依赖（Mapbox SDK、Kotlin 等）
- 编译 Kotlin 代码
- 打包 APK

**预计时间**: 5-15 分钟（取决于网络速度和电脑性能）

## 查看构建进度

在新的终端窗口运行：

```bash
cd example

# 查看构建日志
flutter build apk --debug --verbose

# 或者查看 Gradle 进程
ps aux | grep gradle | grep -v grep
```

## 国内镜像配置（已配置）

### Gradle 镜像
- **腾讯云**: `https://mirrors.cloud.tencent.com/gradle/`
- **阿里云**: `https://mirrors.aliyun.com/macports/distfiles/gradle/`

### Maven 镜像（已在 build.gradle 中配置）
```groovy
allprojects {
    repositories {
        // 阿里云镜像
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/public' }
        maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
        google()
        mavenCentral()
        // Mapbox 仓库
        maven {
            url 'https://api.mapbox.com/downloads/v2/releases/maven'
            authentication { basic(BasicAuthentication) }
            credentials {
                username = "mapbox"
                password = project.findProperty('MAPBOX_DOWNLOADS_TOKEN') ?: System.getenv('MAPBOX_DOWNLOADS_TOKEN')
            }
        }
    }
}
```

## 等待构建完成

构建完成后，你会看到：

```
✓ Built build/app/outputs/flutter-apk/app-debug.apk (XX.XMB)
```

然后就可以运行应用了：

```bash
flutter run
```

## 如果构建失败

### 1. 检查 Gradle daemon
```bash
# 停止所有 Gradle daemon
cd example/android
./gradlew --stop

# 重新构建
cd ..
flutter clean
flutter pub get
flutter build apk --debug
```

### 2. 检查网络连接
```bash
# 测试腾讯云镜像
curl -I https://mirrors.cloud.tencent.com/gradle/

# 测试阿里云镜像
curl -I https://maven.aliyun.com/repository/google
```

### 3. 查看详细日志
```bash
cd example
flutter build apk --debug --verbose 2>&1 | tee build.log
```

## 其他国内镜像选项

### 华为云镜像
```properties
distributionUrl=https\://repo.huaweicloud.com/gradle/gradle-8.6-all.zip
```

### 清华大学镜像
```properties
distributionUrl=https\://mirrors.tuna.tsinghua.edu.cn/gradle/gradle-8.6-all.zip
```

## 验证 Gradle 安装

```bash
cd example/android
./gradlew --version

# 应该显示：
# Gradle 8.6
# Kotlin: 2.1.0
# JVM: 17.x.x
```

## 后续构建

首次构建完成后，后续构建会快很多（通常 1-3 分钟），因为：
- Gradle 已缓存
- 依赖已下载
- 增量编译

## 提示

如果你经常需要构建 Android 项目，建议：

1. **使用 Android Studio**
   - 自动管理 Gradle
   - 更好的错误提示
   - 可视化构建进度

2. **配置全局 Gradle 镜像**
   创建 `~/.gradle/init.gradle`：
   ```groovy
   allprojects {
       repositories {
           maven { url 'https://maven.aliyun.com/repository/google' }
           maven { url 'https://maven.aliyun.com/repository/public' }
           maven { url 'https://maven.aliyun.com/repository/gradle-plugin' }
       }
   }
   ```

3. **增加 Gradle 内存**
   创建 `~/.gradle/gradle.properties`：
   ```properties
   org.gradle.jvmargs=-Xmx4096m -XX:MaxMetaspaceSize=1024m
   org.gradle.parallel=true
   org.gradle.caching=true
   ```

## 当前构建状态

✅ Gradle 8.6 已下载并安装
✅ 配置已更新为使用腾讯云镜像
✅ 构建正在进行中
⏳ 等待构建完成...

请耐心等待构建完成。如果超过 20 分钟还没完成，可以按 Ctrl+C 停止，然后查看日志排查问题。
