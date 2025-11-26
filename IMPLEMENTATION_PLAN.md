# Dayflow 优化项目 - 详细实施计划

## 📋 项目概览

**目标：** 在 macOS 上编译、测试并部署智能帧检测和 Batch API 优化功能

**预期成果：**
- 70-80% 总成本节省
- 60-70% 存储节省
- 功能完整可用

**总预计时间：** 2-4 周（根据投入时间调整）

---

## 🚀 Phase 0: 环境准备（今天，30分钟）

### 任务清单

#### 0.1 验证开发环境 ✅
```bash
# 检查 macOS 版本
sw_vers
# 需要: macOS 13.0+

# 检查 Xcode
xcodebuild -version
# 需要: Xcode 14.0+

# 如果没有 Xcode，从 App Store 安装
open "macapp://itunes.apple.com/app/id497799835"
```

**输出示例：**
```
ProductName:		macOS
ProductVersion:		14.1
BuildVersion:		23B74

Xcode 15.0
Build version 15A240d
```

#### 0.2 准备工作目录
```bash
# 确认在正确的分支
cd ~/path/to/Dayflow  # 替换为您的实际路径
git branch

# 应该看到:
* claude/simplify-frontend-sections-01LbRVuGvvLQ3WRa3oP6YjK3

# 如果不在此分支，切换过去
git checkout claude/simplify-frontend-sections-01LbRVuGvvLQ3WRa3oP6YjK3

# 拉取最新代码
git pull origin claude/simplify-frontend-sections-01LbRVuGvvLQ3WRa3oP6YjK3
```

#### 0.3 检查项目完整性
```bash
# 验证所有新文件存在
ls -la Dayflow/Dayflow/Core/Recording/FrameDifferenceDetector.swift
ls -la Dayflow/Dayflow/Core/AI/GeminiAPIMode.swift
ls -la Dayflow/Dayflow/Core/AI/GeminiBatchAPIClient.swift
ls -la Dayflow/Dayflow/Core/AI/BatchJobQueueManager.swift

# 验证文档存在
ls -la BUILD_GUIDE.md
ls -la BATCH_API_GUIDE.md
ls -la OPTIMIZATION_PLAN.md
```

**验收标准：**
- ✅ Xcode 已安装
- ✅ 在正确的 Git 分支
- ✅ 所有新文件存在
- ✅ 文档齐全

---

## 🔨 Phase 1: 首次编译（今天，1-2小时）

### 任务 1.1: 打开项目 (5分钟)

```bash
# 打开 Xcode 项目
cd ~/path/to/Dayflow
open Dayflow/Dayflow.xcodeproj
```

**Xcode 启动后：**
1. 等待索引完成（顶部显示 "Indexing..." 消失）
2. 观察是否有红色错误标记
3. 查看左侧文件导航器

### 任务 1.2: 解决依赖问题 (10-15分钟)

**检查 Swift Package Manager 依赖：**
```
File → Packages → Resolve Package Versions
```

等待依赖下载完成（可能需要3-5分钟）。

**常见依赖：**
- GRDB (数据库)
- Sentry (错误追踪)
- 其他第三方包

**故障排除：**
```
如果依赖下载失败：
1. File → Packages → Reset Package Caches
2. 重启 Xcode
3. 重新 Resolve Packages
```

### 任务 1.3: 添加新文件到编译目标 (10分钟)

**验证文件是否在编译目标中：**

1. 在左侧找到 `FrameDifferenceDetector.swift`
2. 右键 → Show File Inspector (或 ⌥⌘1)
3. 确保 "Target Membership" 中 "Dayflow" 被勾选

**需要检查的文件：**
- [ ] FrameDifferenceDetector.swift
- [ ] GeminiAPIMode.swift
- [ ] GeminiBatchAPIClient.swift
- [ ] BatchJobQueueManager.swift

**如果未勾选，手动添加：**
1. 点击项目名 "Dayflow"（蓝色图标）
2. 选择 Target "Dayflow"
3. Build Phases → Compile Sources
4. 点击 "+" 添加文件

### 任务 1.4: 配置签名 (5分钟)

```
1. 选择项目 "Dayflow"
2. 选择 Target "Dayflow"
3. Signing & Capabilities 标签
4. Team: 选择 "None" (本地开发)
   或选择您的 Apple ID (如果需要真机运行)
```

### 任务 1.5: 首次编译 (2-5分钟)

```
快捷键: ⌘+B
或
Product → Build
```

**观察编译过程：**
- 顶部显示进度
- 左侧显示正在编译的文件
- 等待完成

**预期结果：**
```
✅ Build Succeeded
顶部显示绿色对勾
```

**如果编译失败：**

#### 错误 A: "No such module 'FrameDifferenceDetector'"
**原因：** 文件未包含在编译中
**解决：** 参见任务 1.3

#### 错误 B: "Use of unresolved identifier"
**原因：** 代码引用了不存在的符号
**解决：**
```bash
# 检查是否有未保存的更改
git status

# 查看具体错误位置
# 点击错误行查看详情
```

#### 错误 C: 签名错误
**解决：** 参见任务 1.4

### 任务 1.6: 首次运行 (5分钟)

```
快捷键: ⌘+R
或
Product → Run
```

**首次运行会：**
1. 请求屏幕录制权限 → **允许**
2. 请求辅助功能权限（可能）→ **允许**
3. 启动应用

**验收标准：**
- ✅ 应用成功启动
- ✅ 看到主界面
- ✅ 侧边栏只有两个图标（Timeline + Settings）

---

## ✅ Phase 2: 功能验证（今天，30-60分钟）

### 任务 2.1: 检查 UI 更新 (5分钟)

**导航到设置：**
```
1. 点击侧边栏 ⚙️ 图标
2. 向下滚动
```

**验证存在以下卡片：**
- [ ] Recording Status (原有)
- [ ] Disk usage (原有)
- [ ] **Smart Frame Detection** (新增 ✨)
- [ ] **Gemini API Mode** (新增 ✨)

**截图对比：**
```bash
# 建议截图保存
# 新设置卡片应该显示：
- 蓝色信息框 (Smart Frame Detection)
- 三段选择器 (Gemini API Mode)
```

### 任务 2.2: 启用优化功能 (5分钟)

#### 2.2.1 启用 Smart Frame Detection
```
Settings → Storage → Smart Frame Detection
→ 打开 "Enable Smart Recording" 开关
```

**观察：**
- 开关变为橙色
- 下方显示 "Detection Mode: Exact Match"
- 蓝色信息框显示预期节省

#### 2.2.2 选择 API Mode
```
Settings → Storage → Gemini API Mode
→ 选择 "Smart Mix" (推荐)
```

**观察：**
- 选择器高亮变为蓝色
- 显示 🧠 brain 图标
- 显示智能模式说明

### 任务 2.3: 测试录制功能 (20分钟)

#### 测试场景 1: 静止屏幕（5分钟）
```
1. 确保录制开关打开
2. 保持屏幕完全静止 2 分钟
3. 不移动鼠标，不操作键盘
```

#### 测试场景 2: 正常工作（10分钟）
```
1. 浏览网页
2. 编辑文档
3. 切换应用
```

#### 测试场景 3: 视频播放（5分钟）
```
1. 播放 YouTube 视频
2. 或播放本地视频
```

### 任务 2.4: 查看日志输出 (10分钟)

**打开 Console.app：**
```
1. Spotlight (⌘+Space)
2. 输入 "Console"
3. 打开 Console.app
```

**配置过滤器：**
```
1. 搜索框输入: process:Dayflow
2. 过滤输入: [Recorder]
```

**预期日志：**

**场景 1 (静止屏幕)：**
```
[Recorder] Segment stats: 2 recorded, 898 skipped (99.8%)
```

**场景 2 (正常工作)：**
```
[Recorder] Segment stats: 320 recorded, 580 skipped (64.4%)
```

**场景 3 (视频播放)：**
```
[Recorder] Segment stats: 850 recorded, 50 skipped (5.6%)
```

### 任务 2.5: 检查文件大小 (10分钟)

**查看录制文件：**
```bash
# 打开录制文件夹
open ~/Library/Application\ Support/Dayflow/recordings/

# 查看今天的文件夹
ls -lh ~/Library/Application\ Support/Dayflow/recordings/$(date +%Y-%m-%d)/

# 计算总大小
du -sh ~/Library/Application\ Support/Dayflow/recordings/$(date +%Y-%m-%d)/
```

**预期结果：**
```
静止时段文件: ~100-500 KB (非常小)
工作时段文件: ~2-5 MB / 15分钟
视频播放文件: ~10-15 MB / 15分钟
```

**对比优化前后：**
```
优化前: ~20 MB / 15分钟 (固定)
优化后: ~2-10 MB / 15分钟 (动态)
平均节省: 60-70%
```

**验收标准：**
- ✅ Console 日志显示帧统计
- ✅ 跳过率在 60-80% 左右
- ✅ 文件大小明显减小
- ✅ UI 响应正常

---

## 🔧 Phase 3: 深度测试（本周，3-5小时）

### 任务 3.1: 长时间运行测试 (24小时)

**设置：**
```
1. 启用所有优化
2. 选择 Smart Mix 模式
3. 正常使用电脑一整天
```

**监控指标：**
```bash
# 创建监控脚本
cat > ~/monitor_dayflow.sh << 'EOF'
#!/bin/bash
echo "=== Dayflow Monitor $(date) ==="
echo "Storage Usage:"
du -sh ~/Library/Application\ Support/Dayflow/recordings/
echo ""
echo "Today's Files:"
ls -lh ~/Library/Application\ Support/Dayflow/recordings/$(date +%Y-%m-%d)/ | tail -10
echo ""
echo "Process Info:"
ps aux | grep Dayflow | grep -v grep
EOF

chmod +x ~/monitor_dayflow.sh

# 每小时运行一次
watch -n 3600 ~/monitor_dayflow.sh
```

**收集数据：**
- [ ] 每小时的存储增长
- [ ] CPU 使用率
- [ ] 内存占用
- [ ] 跳帧统计

### 任务 3.2: API 模式对比测试 (2小时)

**测试矩阵：**

| 时间段 | API 模式 | 预期延迟 | 记录要点 |
|--------|----------|----------|----------|
| 9:00-10:00 | Realtime | 1-2分钟 | 立即生成卡片 |
| 10:00-11:00 | Batch | 5-30分钟 | 延迟但便宜 |
| 11:00-12:00 | Smart | 变化 | 自动切换 |

**记录表格：**
```
时间    | 模式     | 批次完成时间 | 卡片数量 | 备注
--------|----------|--------------|----------|------
09:15   | Realtime | 09:17 (2min) | 3        | 快速
10:20   | Batch    | 10:45 (25min)| 4        | 延迟
11:30   | Smart    | 11:32 (2min) | 3        | 工作时段
```

### 任务 3.3: 性能基准测试 (1小时)

**使用 Instruments 分析：**
```
1. Xcode → Product → Profile (⌘+I)
2. 选择 "Time Profiler"
3. 运行应用 5 分钟
4. 查看 CPU 热点
```

**关注指标：**
- FrameDifferenceDetector 开销
- MD5 计算时间
- 内存分配

**预期结果：**
```
帧检测开销: < 1ms/帧
总 CPU 影响: < 5%
内存增长: < 10MB
```

### 任务 3.4: 边界情况测试 (1小时)

**测试用例：**

#### 用例 1: 快速切换应用
```
1. 快速切换 10+ 个应用
2. 观察帧检测是否正常
3. 检查日志是否有错误
```

#### 用例 2: 系统休眠/唤醒
```
1. 录制中休眠 Mac
2. 5分钟后唤醒
3. 验证录制自动恢复
```

#### 用例 3: 显示器切换
```
1. 外接显示器
2. 断开显示器
3. 验证录制切换正常
```

#### 用例 4: 磁盘空间不足
```
1. 模拟磁盘空间不足
2. 验证应用优雅降级
```

**验收标准：**
- ✅ 24小时稳定运行
- ✅ API 模式切换正常
- ✅ 性能开销可接受
- ✅ 边界情况处理正确

---

## 🚀 Phase 4: 集成与自动化（本周，3-4小时）

### 任务 4.1: 设置 GitHub Actions CI (1小时)

#### 4.1.1 创建 CI 配置文件

我将为您创建 `.github/workflows/build.yml`，包含：

```yaml
功能：
✓ 每次 push 自动编译
✓ PR 时验证能否编译
✓ 显示编译状态
✓ 缓存依赖加速编译
```

#### 4.1.2 配置 Secrets

在 GitHub 仓库设置：
```
Settings → Secrets and variables → Actions
→ New repository secret
```

**可能需要的 Secrets：**
- `GEMINI_API_KEY` (如果需要测试 API)
- `SIGNING_CERTIFICATE` (如果需要签名)

#### 4.1.3 触发首次 CI 构建

```bash
# 创建测试提交
git commit --allow-empty -m "Test CI build"
git push

# 在 GitHub 上查看
# Actions 标签页应该显示构建进度
```

### 任务 4.2: 添加单元测试 (2小时)

#### 4.2.1 FrameDifferenceDetector 测试

创建 `FrameDifferenceDetectorTests.swift`：

```swift
测试用例：
1. testExactHashDetection() - 完全相同的帧应该被跳过
2. testDifferentFrames() - 不同的帧应该被记录
3. testStatistics() - 统计追踪应该正确
4. testConfiguration() - 配置保存/加载应该工作
```

#### 4.2.2 GeminiAPIMode 测试

```swift
测试用例：
1. testSmartModeTiming() - 验证时间切换逻辑
2. testConfigPersistence() - 验证配置持久化
3. testCostCalculation() - 验证成本计算
```

#### 4.2.3 运行测试

```
快捷键: ⌘+U
或
Product → Test
```

### 任务 4.3: 设置持续监控 (1小时)

#### 4.3.1 Analytics 仪表板

如果使用 Sentry 或类似服务：
```
1. 配置自定义仪表板
2. 添加关键指标：
   - frame_diff_toggled 事件
   - gemini_api_mode_changed 事件
   - 跳帧率统计
   - API 使用量
```

#### 4.3.2 告警规则

```
设置告警：
- 跳帧率突然下降（可能是检测失败）
- 崩溃率上升
- API 错误率上升
```

**验收标准：**
- ✅ CI 编译成功
- ✅ 单元测试通过
- ✅ 监控仪表板配置完成

---

## 📈 Phase 5: 优化与完善（下周，5-8小时）

### 任务 5.1: Batch API 完整集成 (3-4小时)

#### 5.1.1 数据库 Schema 扩展

创建迁移脚本：
```sql
-- batch_jobs 表
CREATE TABLE IF NOT EXISTS batch_jobs (
    id TEXT PRIMARY KEY,
    batch_id INTEGER NOT NULL,
    gemini_job_name TEXT,
    status TEXT NOT NULL,
    created_at REAL NOT NULL,
    submitted_at REAL,
    completed_at REAL,
    request_payload TEXT,
    response_data TEXT,
    error_message TEXT,
    FOREIGN KEY (batch_id) REFERENCES analysis_batches(id)
);

-- 索引
CREATE INDEX IF NOT EXISTS idx_batch_jobs_status
ON batch_jobs(status);

CREATE INDEX IF NOT EXISTS idx_batch_jobs_batch_id
ON batch_jobs(batch_id);
```

#### 5.1.2 修改 GeminiDirectProvider

添加 batch 模式支持：
```swift
func transcribeVideo(..., useBatchAPI: Bool) async throws -> ... {
    if useBatchAPI {
        // 使用 Batch API 路径
        return try await submitBatchJob(...)
    } else {
        // 使用现有 Files API 路径
        return try await submitRealtimeJob(...)
    }
}
```

#### 5.1.3 集成 BatchJobQueueManager

```swift
// 在 AppDelegate 中启动
func applicationDidFinishLaunching(...) {
    ...
    BatchJobQueueManager.shared.startPolling()
}
```

### 任务 5.2: 用户体验优化 (2-3小时)

#### 5.2.1 添加统计显示

在 Settings 中添加实时统计：
```swift
// 新增卡片
SettingsCard(title: "Optimization Statistics") {
    VStack {
        StatRow(label: "Frames Saved Today",
                value: "\(stats.skippedFrames)")
        StatRow(label: "Storage Saved",
                value: formatBytes(stats.savedBytes))
        StatRow(label: "Skip Rate",
                value: "\(Int(stats.skipRate * 100))%")
    }
}
```

#### 5.2.2 添加通知

Batch 完成时通知：
```swift
if batchCompleted {
    let notification = NSUserNotification()
    notification.title = "Timeline Updated"
    notification.informativeText = "3 new activity cards generated"
    NSUserNotificationCenter.default.deliver(notification)
}
```

#### 5.2.3 添加队列状态指示

在 Timeline 中显示：
```swift
if hasPendingBatches {
    HStack {
        ProgressView()
        Text("Processing in background...")
    }
}
```

### 任务 5.3: 性能微调 (1小时)

#### 5.3.1 帧检测算法优化

```swift
// 可选：添加并行哈希计算
private let hashQueue = DispatchQueue(
    label: "com.dayflow.hash",
    qos: .userInitiated,
    attributes: .concurrent
)
```

#### 5.3.2 内存优化

```swift
// 使用 autoreleasepool 避免内存峰值
autoreleasepool {
    let hash = computeMD5Hash(pixelBuffer)
    ...
}
```

#### 5.3.3 缓存优化

```swift
// 缓存最近的哈希值
private var hashCache = LRUCache<String, String>(capacity: 10)
```

**验收标准：**
- ✅ Batch API 完整工作
- ✅ 用户体验流畅
- ✅ 性能优化完成

---

## 🎯 Phase 6: 发布准备（下周，2-3小时）

### 任务 6.1: 文档更新 (1小时)

#### 6.1.1 更新 README
```markdown
添加：
- 新功能说明
- 使用指南
- FAQ
- 已知问题
```

#### 6.1.2 创建 CHANGELOG
```markdown
## v2.0.0 (2024-XX-XX)

### Added
- 智能帧差异检测（60-70%存储节省）
- Gemini Batch API 支持（50%成本节省）
- 三种 API 模式选择

### Changed
- 简化前端至 Timeline 和 Settings

### Performance
- 减少 70-80% 总运营成本
```

### 任务 6.2: 发布构建 (1小时)

#### 6.2.1 创建 Release 配置

```
Xcode → Product → Archive
→ Distribute App
→ Copy App (本地分发)
或
→ Developer ID (签名分发)
```

#### 6.2.2 创建 DMG 安装包

```bash
# 使用 create-dmg 工具
brew install create-dmg

create-dmg \
  --volname "Dayflow v2.0" \
  --window-size 600 400 \
  --icon-size 100 \
  --app-drop-link 450 120 \
  Dayflow-v2.0.dmg \
  Dayflow.app
```

### 任务 6.3: 创建 GitHub Release (30分钟)

```bash
# 创建 tag
git tag -a v2.0.0 -m "Major optimization release"
git push origin v2.0.0

# 在 GitHub 上
# Releases → Create a new release
# 上传 DMG 文件
# 添加 Release Notes
```

**验收标准：**
- ✅ 文档完整更新
- ✅ Release 构建成功
- ✅ GitHub Release 发布

---

## 📊 总体时间表

### 第 1 天（今天）
```
✓ Phase 0: 环境准备 (30min)
✓ Phase 1: 首次编译 (1-2h)
✓ Phase 2: 功能验证 (30-60min)
---
总计: 2-3.5 小时
```

### 第 2-3 天（本周）
```
✓ Phase 3: 深度测试 (3-5h)
✓ Phase 4: 集成与自动化 (3-4h)
---
总计: 6-9 小时
```

### 第 4-5 天（下周）
```
✓ Phase 5: 优化与完善 (5-8h)
✓ Phase 6: 发布准备 (2-3h)
---
总计: 7-11 小时
```

### **总投入时间: 15-23.5 小时**
- 最快路径: 15 小时（跳过可选任务）
- 完整路径: 23.5 小时（包含所有任务）
- 建议节奏: 每天 2-3 小时，一周完成

---

## ✅ 验收标准

### 核心功能验收
- [ ] 编译成功，无错误
- [ ] 应用稳定运行 24+ 小时
- [ ] 帧检测跳过率 60-80%
- [ ] 文件大小减少 60-70%
- [ ] API 模式切换正常
- [ ] 所有设置 UI 正常显示

### 质量验收
- [ ] 无内存泄漏
- [ ] CPU 使用率 < 5%
- [ ] 所有单元测试通过
- [ ] CI 构建通过
- [ ] 边界情况处理正确

### 文档验收
- [ ] BUILD_GUIDE.md 准确
- [ ] BATCH_API_GUIDE.md 完整
- [ ] CHANGELOG 更新
- [ ] README 更新

---

## 🆘 故障排除预案

### 问题 A: 编译失败
```
优先级: P0 (立即解决)
预计时间: 30分钟

解决步骤:
1. 检查错误日志
2. 验证文件完整性
3. 清理缓存重新编译
4. 查看 BUILD_GUIDE.md 故障排除章节
```

### 问题 B: 帧检测不工作
```
优先级: P1 (当天解决)
预计时间: 1小时

诊断步骤:
1. 查看 Console 日志
2. 确认配置已保存
3. 验证帧检测器初始化
4. 检查权限设置
```

### 问题 C: Batch API 集成问题
```
优先级: P2 (本周解决)
预计时间: 2-3小时

解决策略:
1. 暂时使用 Realtime 模式
2. 逐步调试 Batch 集成
3. 参考 BATCH_API_GUIDE.md
4. 使用 Postman 测试 API
```

---

## 📞 支持资源

### 文档
- BUILD_GUIDE.md - 编译指南
- BATCH_API_GUIDE.md - API 使用
- OPTIMIZATION_PLAN.md - 优化方案

### 工具
- Console.app - 查看日志
- Instruments - 性能分析
- Xcode Debugger - 断点调试

### 社区
- GitHub Issues - 报告问题
- 代码注释 - 实现细节

---

## 🎯 里程碑

### Milestone 1: 可用原型（第1天完成）
- 编译成功
- 优化功能可启用
- 基本测试通过

### Milestone 2: 稳定版本（第3天完成）
- 长时间稳定运行
- 所有测试通过
- CI/CD 配置完成

### Milestone 3: 生产就绪（第5天完成）
- Batch API 完整集成
- 用户体验优化
- 文档齐全

### Milestone 4: 正式发布（第7天完成）
- Release 构建
- GitHub Release
- 公开分发

---

## 📈 成功指标

### 技术指标
- 编译成功率: 100%
- 测试通过率: 100%
- 代码覆盖率: > 60%
- 性能开销: < 5% CPU

### 业务指标
- 存储节省: 60-70%
- API 成本节省: 70-80%
- 用户体验: 流畅无感知
- 系统稳定性: 无崩溃

---

**准备好开始了吗？建议从 Phase 0 和 Phase 1 开始！** 🚀
