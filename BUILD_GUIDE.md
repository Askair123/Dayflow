# Dayflow 编译指南 - 第一次编译

## 📋 前提条件

### 必需环境
- ✅ **macOS 系统** (macOS 13 Ventura 或更高版本推荐)
- ✅ **Xcode 14.0+** (从 Mac App Store 免费下载)
- ✅ **命令行工具** (Xcode 会自动安装)

### 检查您的 macOS 版本
```bash
sw_vers
```

### 检查 Xcode 是否已安装
```bash
xcodebuild -version
```

如果看到类似 `Xcode 15.0` 的输出，说明已安装。

---

## 🚀 编译步骤（逐步指导）

### 步骤 1: 克隆或拉取最新代码

如果您还没有本地副本：
```bash
git clone <repository-url>
cd Dayflow
```

如果已有本地副本，拉取最新更改：
```bash
cd Dayflow
git pull origin claude/simplify-frontend-sections-01LbRVuGvvLQ3WRa3oP6YjK3
```

### 步骤 2: 检查项目文件

确认项目文件存在：
```bash
ls -la Dayflow/

# 您应该看到：
# - Dayflow.xcodeproj/    (Xcode 项目文件)
# - Dayflow/              (源代码目录)
# - DayflowTests/         (测试文件)
```

### 步骤 3: 打开 Xcode 项目

#### 方式 A: 使用命令行
```bash
open Dayflow/Dayflow.xcodeproj
```

#### 方式 B: 使用 Finder
1. 双击 `Dayflow.xcodeproj` 文件
2. Xcode 将自动打开

---

## 🔧 Xcode 中的编译步骤

### 第一次打开时的设置

1. **等待 Xcode 索引完成**
   - Xcode 顶部会显示 "Indexing..."
   - 首次打开可能需要 1-2 分钟
   - 等待完成后再继续

2. **选择开发团队** (如果提示)
   - 点击项目名称 "Dayflow"
   - 选择 "Signing & Capabilities" 标签
   - 在 "Team" 下拉框中选择您的 Apple ID
   - 如果没有，点击 "Add Account..." 登录

3. **选择运行目标**
   - Xcode 顶部工具栏左侧
   - 点击设备选择器 (默认可能是 "My Mac")
   - 确保选择 "My Mac (Mac - arm64)" 或类似选项

### 编译项目

#### 方法 1: 使用 Xcode GUI (推荐初次使用)

1. **快捷键编译**
   ```
   按 ⌘ + B (Command + B)
   ```

2. **或者点击菜单**
   ```
   Product → Build
   ```

3. **查看编译进度**
   - Xcode 顶部会显示编译进度
   - 左侧导航栏会显示正在编译的文件
   - 等待编译完成（首次编译可能需要 2-5 分钟）

4. **检查编译结果**
   - ✅ 成功: 顶部显示 "Build Succeeded"
   - ❌ 失败: 左侧会显示错误列表

#### 方法 2: 使用命令行 (进阶用户)

```bash
cd Dayflow

# 清理之前的编译缓存
xcodebuild clean -project Dayflow.xcodeproj -scheme Dayflow

# 编译项目
xcodebuild build \
  -project Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Debug \
  -destination 'platform=macOS,arch=x86_64' \
  | tee build.log

# 如果是 Apple Silicon (M1/M2) Mac:
xcodebuild build \
  -project Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  | tee build.log
```

---

## 🏃 运行应用

### 编译成功后运行

#### 方法 1: Xcode 中运行
```
按 ⌘ + R (Command + R)
或
Product → Run
```

#### 方法 2: 查看编译产物
```bash
# 编译产物位置
ls -la ~/Library/Developer/Xcode/DerivedData/Dayflow-*/Build/Products/Debug/

# 直接运行
open ~/Library/Developer/Xcode/DerivedData/Dayflow-*/Build/Products/Debug/Dayflow.app
```

---

## 🐛 常见编译错误及解决方案

### 错误 1: 签名错误
```
Code Signing Error: "Dayflow" requires a development team.
```

**解决方案:**
1. 在 Xcode 中选择项目
2. Signing & Capabilities 标签
3. Team 选择你的 Apple ID
4. 如果没有账号，选择 "None" (本地开发可用)

---

### 错误 2: 缺少依赖
```
No such module 'GRDB' or 'Sentry'
```

**解决方案:**
1. 检查是否有 Package.swift 或 Podfile
2. 如果使用 Swift Package Manager:
   ```
   File → Packages → Resolve Package Versions
   ```
3. 如果使用 CocoaPods:
   ```bash
   pod install
   # 然后打开 Dayflow.xcworkspace 而不是 .xcodeproj
   ```

---

### 错误 3: 新增文件未包含在编译中
```
Use of unresolved identifier 'FrameDifferenceDetector'
```

**解决方案:**
1. 在 Xcode 左侧文件导航器中找到该文件
2. 右键点击文件 → "Show File Inspector"
3. 确保 "Target Membership" 中 Dayflow 被选中

**或者手动添加:**
1. 选择项目 "Dayflow" (顶部蓝色图标)
2. 选择 Target "Dayflow"
3. "Build Phases" 标签
4. 展开 "Compile Sources"
5. 点击 "+" 添加缺失的文件：
   - FrameDifferenceDetector.swift
   - GeminiAPIMode.swift
   - GeminiBatchAPIClient.swift
   - BatchJobQueueManager.swift

---

### 错误 4: 权限错误
```
Sandbox: deny(1) file-read-data
```

**解决方案:**
这是正常的沙盒限制。运行时会请求权限。

---

## ✅ 验证优化功能

### 编译成功后的测试步骤

#### 1. 启动应用
```
运行 Dayflow.app
```

#### 2. 检查设置界面

**导航到设置:**
1. 点击左侧边栏的 ⚙️ 图标
2. 滚动到页面底部

**您应该看到两个新的设置卡片:**

✅ **Smart Frame Detection**
- 位置: Disk usage 下方
- 内容: Enable Smart Recording 开关
- 颜色: 蓝色信息框显示节省预期

✅ **Gemini API Mode**
- 位置: Smart Frame Detection 下方
- 内容: 三段选择器 (Realtime | Batch | Smart Mix)
- 视觉: 动态图标和颜色变化

#### 3. 启用优化功能

**启用帧检测:**
```
Settings → Storage → Smart Frame Detection
→ 打开 "Enable Smart Recording" 开关
```

**选择 API 模式:**
```
Settings → Storage → Gemini API Mode
→ 选择 "Smart Mix" (推荐)
```

#### 4. 测试录制

**开始录制:**
1. 点击顶部的 "Record" 按钮
2. 如果提示权限，点击 "允许"

**测试场景 1: 静止屏幕**
1. 保持屏幕静止 1-2 分钟
2. 打开 Console.app (搜索 "Console")
3. 搜索 "Recorder"
4. 查找类似日志:
   ```
   [Recorder] Segment stats: 3 recorded, 117 skipped (97.5%)
   ```

**测试场景 2: 正常工作**
1. 正常浏览网页、编辑文档 5 分钟
2. 检查 Console 日志
3. 应该看到约 60-80% 跳过率

#### 5. 检查文件大小

**对比文件大小:**
```bash
# 查看录制文件
ls -lh ~/Library/Application\ Support/Dayflow/recordings/*/

# 计算总大小
du -sh ~/Library/Application\ Support/Dayflow/recordings/
```

**预期效果:**
- 静止时段: 文件非常小 (~100KB)
- 活跃时段: 文件适中 (~2-5MB/15分钟)

---

## 📊 监控和日志

### 实时日志查看

**方法 1: Console.app**
```
1. 打开 Console.app (Spotlight 搜索 "Console")
2. 在搜索框输入: process:Dayflow
3. 过滤器输入: [Recorder] 或 [BatchAPI]
```

**方法 2: 命令行**
```bash
# 实时查看 Dayflow 日志
log stream --predicate 'process == "Dayflow"' --level debug

# 只看帧检测日志
log stream --predicate 'process == "Dayflow"' | grep "\[Recorder\]"

# 只看 Batch API 日志
log stream --predicate 'process == "Dayflow"' | grep "\[Batch"
```

### 关键日志标识符

```
[Recorder] - 录制相关日志
  └─ Segment stats: X recorded, Y skipped (Z%)

[BatchAPI] - Batch API 操作
  └─ Submitting batch request with N items
  └─ Batch job created: batches/xyz

[BatchQueue] - 队列管理
  └─ Polling started (interval: 120s)
  └─ Job xyz status: PROCESSING

[FrameDiff] - 帧差异检测 (如果添加了调试日志)
```

---

## 🔬 高级调试

### Debug 模式编译

如果遇到问题，使用 Debug 模式获取更多信息:

```bash
xcodebuild build \
  -project Dayflow.xcodeproj \
  -scheme Dayflow \
  -configuration Debug \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

### 启用详细日志

在 Xcode 中:
1. Product → Scheme → Edit Scheme
2. Run → Arguments
3. Environment Variables 添加:
   ```
   DAYFLOW_DEBUG_LOGGING = 1
   ```

### 查看崩溃报告

如果应用崩溃:
```bash
# 查看崩溃日志
open ~/Library/Logs/DiagnosticReports/

# 搜索 Dayflow 相关
ls -lt ~/Library/Logs/DiagnosticReports/ | grep Dayflow
```

---

## 📱 性能分析

### 使用 Instruments 分析

```bash
# 启动 Instruments
instruments -t "Time Profiler" -D trace.trace -l 60000 Dayflow.app

# 或在 Xcode 中
# Product → Profile (⌘ + I)
```

### 监控指标

**CPU 使用:**
```bash
# 实时监控
top -pid $(pgrep Dayflow)
```

**内存使用:**
```bash
# 查看内存占用
ps aux | grep Dayflow
```

**磁盘使用:**
```bash
# 查看录制文件增长
watch -n 5 'du -sh ~/Library/Application\ Support/Dayflow/recordings/'
```

---

## 💡 编译优化建议

### 加快编译速度

**1. 启用并行编译**
```
Xcode → Preferences → Locations → Derived Data
→ Advanced → Build System → New Build System
```

**2. 使用增量编译**
```bash
# 只编译更改的文件
xcodebuild build -project Dayflow.xcodeproj -scheme Dayflow -derivedDataPath ./DerivedData
```

**3. 清理缓存（如果遇到奇怪问题）**
```bash
# 清理 Xcode 缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/Dayflow-*

# 在 Xcode 中
# Product → Clean Build Folder (⇧ ⌘ K)
```

---

## 🎯 下一步

编译成功后，建议：

1. ✅ **运行应用** - 熟悉界面
2. ✅ **启用优化** - 打开帧检测和 Smart API 模式
3. ✅ **测试 1 小时** - 正常使用，观察效果
4. ✅ **检查日志** - 确认优化正在工作
5. ✅ **对比数据** - 查看存储节省效果

---

## 📞 遇到问题？

### 检查清单

- [ ] macOS 版本 ≥ 13.0
- [ ] Xcode 版本 ≥ 14.0
- [ ] 所有新文件已添加到编译目标
- [ ] 代码签名配置正确
- [ ] 依赖包已解析
- [ ] 构建缓存已清理

### 日志收集

如果需要报告问题，请收集：

```bash
# 1. 编译日志
xcodebuild build ... 2>&1 | tee build.log

# 2. 运行时日志
log show --predicate 'process == "Dayflow"' --last 10m > runtime.log

# 3. 系统信息
system_profiler SPSoftwareDataType > system_info.txt
```

---

## 🎉 成功标志

当您看到以下内容时，表示一切正常：

✅ Xcode 显示 "Build Succeeded"
✅ 应用成功启动
✅ Settings 中看到两个新的优化卡片
✅ Console 中看到 `[Recorder] Segment stats` 日志
✅ 跳过率在 60-80% 左右

**恭喜！您已成功编译并启用了 Dayflow 的优化功能！** 🚀

---

## 📚 参考资源

- [Xcode 用户指南](https://developer.apple.com/documentation/xcode)
- [Swift 包管理器](https://swift.org/package-manager/)
- [macOS App 开发](https://developer.apple.com/macos/)
- [ScreenCaptureKit 文档](https://developer.apple.com/documentation/screencapturekit)
