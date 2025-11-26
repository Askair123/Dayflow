# Dayflow 优化方案：Batch API + 智能帧检测

## 优化目标

1. **减少 API 成本 50-70%** - 通过 Batch API 和智能录制
2. **减少存储占用 60-80%** - 通过帧差异检测
3. **保持分析质量** - 不影响时间线卡片准确性

---

## 优化 1: Gemini Batch API 集成

### 当前架构问题
```swift
// GeminiDirectProvider.swift
// 当前：实时 File API + 即时 generateContent 调用
1. 上传视频到 File API
2. 立即调用 generateContent（同步等待）
3. 成本：标准价格
```

### Batch API 优势
- ✅ **成本降低 50%** - Batch API 价格是实时 API 的一半
- ✅ **更高配额** - 每日请求限制更宽松
- ✅ **适合非实时场景** - Dayflow 不需要秒级响应

### Batch API 限制
- ⚠️ **处理延迟** - 可能需要几分钟到24小时
- ⚠️ **需要轮询** - 异步获取结果
- ⚠️ **复杂度增加** - 需要任务队列和状态管理

### 设计方案：混合模式

```
用户可在设置中选择：

模式 A: 实时模式（Files API）
├─ 优点：即时生成卡片（1-2分钟）
├─ 缺点：成本高
└─ 适合：需要及时反馈的用户

模式 B: 批处理模式（Batch API）
├─ 优点：成本降低50%
├─ 缺点：延迟5-30分钟
└─ 适合：对延迟不敏感的用户

模式 C: 智能混合（推荐）
├─ 工作时段 → 实时模式
├─ 空闲时段 → 批处理模式
└─ 夜间补偿 → 批处理所有积压
```

---

## 优化 2: 智能帧差异检测

### 当前架构问题
```swift
// ScreenRecorder.swift:19
static let fps: Int32 = 1  // 固定每秒1帧

问题：
- 屏幕静止时仍然录制 → 浪费存储
- 长时间空闲产生大量重复帧
- 15分钟batch可能包含90%相同内容
```

### 帧差异检测算法

#### 方案A：像素哈希比较（推荐）
```swift
优点：
✅ 快速（<1ms）
✅ 准确检测完全相同的帧
✅ 内存占用低

算法：
1. 计算当前帧的 MD5/SHA256 哈希
2. 与前一帧哈希比较
3. 不同 → 保存帧
4. 相同 → 跳过帧

伪代码：
var lastFrameHash: String? = nil

func shouldRecordFrame(_ buffer: CVPixelBuffer) -> Bool {
    let currentHash = computeHash(buffer)
    defer { lastFrameHash = currentHash }

    guard let previous = lastFrameHash else { return true }
    return currentHash != previous
}
```

#### 方案B：感知哈希（更智能）
```swift
优点：
✅ 检测微小变化（如光标移动）
✅ 可调节敏感度阈值
✅ 识别实质性内容变化

算法：
1. 缩小图像到 8x8 或 16x16
2. 转换为灰度
3. 计算 DCT（离散余弦变换）
4. 提取低频信息作为哈希
5. 计算汉明距离

阈值设置：
- 距离 0-5  → 相同（跳过）
- 距离 6-15 → 微小变化（可选跳过）
- 距离 >15  → 显著变化（保存）
```

#### 方案C：区域差异检测（最优）
```swift
优点：
✅ 可以标记变化区域
✅ 未来可支持裁剪（仅保存变化区域）
✅ 更精确的差异判断

算法：
1. 将帧分为 N x M 网格（如 16x16）
2. 对每个网格块计算哈希
3. 统计变化块的比例

阈值策略：
- 变化 <5%   → 跳过（如光标移动）
- 变化 5-20% → 局部变化（保存）
- 变化 >20%  → 显著变化（保存）

未来扩展：
→ 仅保存变化区域的视频裁剪版本
→ 进一步减少 50-70% 文件大小
```

### 预期效果

#### 场景分析
```
场景1：长时间阅读文档（静止）
- 当前：900帧/15分钟 (~20MB)
- 优化后：1-10帧 (~0.2-2MB)
- 节省：90-99%

场景2：观看视频（屏幕持续变化）
- 当前：900帧/15分钟 (~20MB)
- 优化后：800-900帧 (~18-20MB)
- 节省：0-10%

场景3：编程工作（间歇变化）
- 当前：900帧/15分钟 (~20MB)
- 优化后：200-400帧 (~4-8MB)
- 节省：55-80%

平均预期：
- 存储减少：60-70%
- API数据传输减少：60-70%
- 处理时间减少：40-50%
```

---

## 实施细节

### 1. 数据库 Schema 扩展

```sql
-- 记录每个chunk的帧数统计
ALTER TABLE recording_chunks ADD COLUMN total_frames INTEGER DEFAULT 0;
ALTER TABLE recording_chunks ADD COLUMN unique_frames INTEGER DEFAULT 0;
ALTER TABLE recording_chunks ADD COLUMN skip_rate REAL DEFAULT 0.0;

-- API 模式偏好
CREATE TABLE IF NOT EXISTS user_preferences (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

INSERT INTO user_preferences (key, value)
VALUES ('gemini_api_mode', 'realtime');  -- 'realtime' | 'batch' | 'smart'
```

### 2. 配置选项

```swift
// 新增：GeminiAPIMode.swift
enum GeminiAPIMode: String, Codable {
    case realtime  // Files API，即时响应
    case batch     // Batch API，延迟但便宜
    case smart     // 智能混合模式
}

// 新增：FrameDifferenceConfig.swift
struct FrameDifferenceConfig {
    let enabled: Bool = true
    let algorithm: DiffAlgorithm = .perceptualHash
    let threshold: Double = 0.15  // 15% 变化

    enum DiffAlgorithm {
        case exactHash      // MD5/SHA256
        case perceptualHash // pHash
        case regionBased    // 区域差异
    }
}
```

### 3. 设置界面扩展

```swift
// SettingsView.swift - 新增 "Recording Optimization" 卡片

SettingsCard(
    title: "Recording Optimization",
    subtitle: "Reduce storage and API costs with intelligent frame detection"
) {
    VStack(alignment: .leading, spacing: 16) {
        // 帧差异检测开关
        Toggle(isOn: $frameDiffEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Frame Detection")
                    .font(.custom("Nunito", size: 14))
                    .fontWeight(.semibold)
                Text("Only record frames when screen content changes")
                    .font(.custom("Nunito", size: 12))
                    .foregroundColor(.black.opacity(0.55))
            }
        }

        // 敏感度滑块
        if frameDiffEnabled {
            VStack(alignment: .leading, spacing: 8) {
                Text("Detection Sensitivity: \(Int(sensitivity * 100))%")
                    .font(.custom("Nunito", size: 12))
                Slider(value: $sensitivity, in: 0.05...0.5)
                Text("Lower = Skip more similar frames")
                    .font(.custom("Nunito", size: 11))
                    .foregroundColor(.black.opacity(0.45))
            }
        }

        // 统计信息
        HStack {
            StatBox(label: "Frames Saved", value: "\(skippedFrames)")
            StatBox(label: "Storage Saved", value: formatBytes(savedBytes))
        }
    }
}

// API 模式选择卡片
SettingsCard(
    title: "Gemini API Mode",
    subtitle: "Choose between speed and cost"
) {
    Picker("API Mode", selection: $geminiAPIMode) {
        Text("Realtime (Faster, $$$)").tag(GeminiAPIMode.realtime)
        Text("Batch (Slower, $)").tag(GeminiAPIMode.batch)
        Text("Smart Mix (Recommended)").tag(GeminiAPIMode.smart)
    }
    .pickerStyle(.segmented)

    // 模式说明
    switch geminiAPIMode {
    case .realtime:
        InfoBox("Cards generated within 1-2 minutes. Higher cost.")
    case .batch:
        InfoBox("Cards generated within 5-30 minutes. 50% cost savings.")
    case .smart:
        InfoBox("Uses realtime during work hours, batch otherwise.")
    }
}
```

---

## 性能预测

### API 成本对比（每月100小时录制）

| 场景 | 当前成本 | 优化后成本 | 节省 |
|-----|---------|-----------|------|
| **Files API（当前）** | $15-20 | - | 0% |
| **帧检测 + Files API** | - | $6-8 | 60% |
| **Batch API** | - | $7.5-10 | 50% |
| **帧检测 + Batch API** | - | **$3-4** | **80%** |

### 存储成本对比（每月100小时录制）

| 场景 | 存储占用 | 优化 |
|-----|---------|------|
| **当前（固定1 FPS）** | ~50-100 GB | 0% |
| **帧差异检测** | ~15-40 GB | **60-70%** |

### 处理速度提升

| 阶段 | 当前时间 | 优化后 | 提升 |
|-----|---------|--------|------|
| 视频合并 | 2-5秒 | 1-2秒 | 50% |
| 上传到Gemini | 10-30秒 | 3-10秒 | 70% |
| 总处理时间 | 60-90秒 | 25-45秒 | 50% |

---

## 实施路线图

### Phase 1: 帧差异检测（1-2周）
- [ ] 实现 MD5 哈希帧比较
- [ ] 在 ScreenRecorder 中集成检测逻辑
- [ ] 添加统计追踪（跳过帧数、节省空间）
- [ ] 创建设置界面

### Phase 2: 高级差异算法（2-3周）
- [ ] 实现感知哈希（pHash）
- [ ] 实现区域差异检测
- [ ] 添加敏感度调节
- [ ] A/B 测试不同算法效果

### Phase 3: Batch API 集成（3-4周）
- [ ] 实现 Gemini Batch API 客户端
- [ ] 创建任务队列和状态管理
- [ ] 实现轮询机制获取结果
- [ ] 添加智能混合模式

### Phase 4: 测试和优化（1-2周）
- [ ] 性能测试和基准测试
- [ ] 用户验收测试
- [ ] 文档更新
- [ ] 发布

---

## 技术风险与缓解

### 风险1: 帧检测误判
**问题：** 跳过了包含重要信息的帧
**缓解：**
- 保守的阈值设置（宁可多录不少录）
- 用户可调节敏感度
- 记录跳过统计供用户查看

### 风险2: Batch API 延迟过长
**问题：** 用户等待时间过长影响体验
**缓解：**
- 默认使用 Smart 模式（工作时段实时）
- 提供明确的延迟预期
- 支持手动触发紧急处理

### 风险3: 计算开销增加
**问题：** 帧哈希计算影响录制性能
**缓解：**
- 使用快速哈希算法（MD5）
- 异步计算（不阻塞录制）
- 可选择禁用优化

---

## 监控指标

### 新增分析事件

```swift
// 帧检测统计
AnalyticsService.capture("frame_detection_stats", [
    "total_frames": 900,
    "unique_frames": 320,
    "skip_rate": 0.64,
    "storage_saved_mb": 12.5
])

// API模式使用
AnalyticsService.capture("api_mode_switched", [
    "from": "realtime",
    "to": "batch",
    "reason": "user_setting"
])

// Batch API性能
AnalyticsService.capture("batch_api_completed", [
    "batch_id": 12345,
    "latency_minutes": 8.5,
    "cost_savings_percent": 50
])
```

---

## 总结

这两个优化将为 Dayflow 带来：

✅ **API 成本降低 70-80%** （帧检测 + Batch API）
✅ **存储占用减少 60-70%** （智能录制）
✅ **处理速度提升 50%** （更少数据传输）
✅ **保持分析质量** （无损失，甚至因为数据更精炼而提升）

用户获得的价值：
- 更低的运行成本
- 更快的处理速度
- 更少的存储占用
- 灵活的配置选项

这是一个**高投资回报率**的优化，强烈建议优先实施！
