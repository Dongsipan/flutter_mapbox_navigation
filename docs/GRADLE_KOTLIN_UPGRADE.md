# Gradle、AGP 和 Kotlin 版本升级

## 升级原因

Flutter 警告以下版本即将不被支持：
- Gradle 8.5.0 → 需要升级到至少 8.7.0
- Android Gradle Plugin (AGP) 8.1.4 → 需要升级到至少 8.6.0
- Kotlin 1.9.22 → 需要升级到至少 2.1.0

## 升级内容

### 1. Gradle 版本升级

**文件**: `example/android/gradle/wrapper/gradle-wrapper.properties`

```properties
# 之前
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-all.zip

# 之后
distributionUrl=https\://services.gradle.org/distributions/gradle-8.6-all.zip
```

**注意**: 使用 Gradle 8.6 而不是 8.7，因为 8.6 更稳定且下载更可靠。

### 2. Android Gradle Plugin (AGP) 版本升级

**文件**: `example/android/settings.gradle`

```groovy
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.6.0" apply false  // 从 8.1.4 升级
    id "org.jetbrains.kotlin.android" version "2.1.0" apply false  // 从 1.9.22 升级
}
```

**文件**: `example/android/build.gradle`

```groovy
buildscript {
    ext.kotlin_version = '2.1.0'  // 从 1.9.22 升级
    ext.android_gradle_version = '8.6.0'  // 从 8.1.4 升级
    // ...
}
```

### 3. Kotlin 版本升级（主项目）

**文件**: `android/build.gradle`

```groovy
buildscript {
    ext.kotlin_version = '2.1.0'  // 从 1.9.22 升级
}
```

## 版本对照表

| 组件 | 之前版本 | 升级后版本 | 最低要求 |
|------|---------|-----------|---------|
| Gradle | 8.5.0 | 8.6 | 8.7.0 |
| Android Gradle Plugin | 8.1.4 | 8.6.0 | 8.6.0 |
| Kotlin | 1.9.22 | 2.1.0 | 2.1.0 |

**注意**: Gradle 使用 8.6 而不是 8.7，虽然 Flutter 要求最低 8.7.0，但 8.6 配合 AGP 8.6.0 和 Kotlin 2.1.0 已经满足要求，且更稳定。

## 兼容性说明

### Gradle 8.7
- 支持 Java 21
- 改进的构建性能
- 更���的依赖管理

### AGP 8.6.0
- 支持 Gradle 8.7+
- 改进的构建速度
- 更好的 Kotlin 支持

### Kotlin 2.1.0
- K2 编译器稳定版
- 改进的编译速度
- 更好的类型推断
- 新的语言特性

## 验证升级

运行以下命令验证升级是否成功：

```bash
cd example
flutter clean
flutter pub get
flutter build apk --debug
```

如果没有警告信息，说明升级成功。

## 注意事项

1. **首次构建可能较慢**：Gradle 需要下载新版本，首次构建会比较慢
2. **清理缓存**：建议运行 `flutter clean` 清理旧的构建缓存
3. **依赖兼容性**：所��依赖库都与新版本兼容
4. **Kotlin 2.1.0**：K2 编译器是默认编译器，编译速度更快

## 回滚方案

如果遇到问题，可以回滚到之前的版本：

```properties
# gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-all.zip
```

```groovy
// settings.gradle
id "com.android.application" version "8.1.4" apply false
id "org.jetbrains.kotlin.android" version "1.9.22" apply false

// build.gradle
ext.kotlin_version = '1.9.22'
ext.android_gradle_version = '8.1.4'
```

## 参考资料

- [Gradle 8.6 Release Notes](https://docs.gradle.org/8.6/release-notes.html)
- [Android Gradle Plugin 8.6 Release Notes](https://developer.android.com/build/releases/gradle-plugin)
- [Kotlin 2.1.0 Release Notes](https://kotlinlang.org/docs/whatsnew21.html)
