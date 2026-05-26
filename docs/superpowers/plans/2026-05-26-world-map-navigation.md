# 大地图寻路与全屏 UI 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现按下 M 键开启精美的全屏水墨风地图，支持点击寻路和 WASD 打断。

**Architecture:** 采用 Godot AStar2D 进行网格寻路，通过单例或系统组件管理地图阻挡。PlayerController 引入自动移动状态，在检测到手动输入时立即释放控制权。

**Tech Stack:** Godot 4.x (GDScript), AStar2D, CanvasItem Drawing (水墨效果)。

---

### Task 1: 基础寻路系统实现

**Files:**
- Create: `scripts/systems/world_navigation_system.gd`
- Test: `tests/test_world_navigation_system.gd`

- [x] **Step 1: 编写寻路系统单元测试** (Pending Implementation)
- [ ] **Step 2: 实现 AStar 网格初始化**
- [ ] **Step 3: 运行并验证寻路逻辑**

---

### Task 2: 角色控制器增强 (自动移动与打断)

**Files:**
- Modify: `scripts/scenes/player_controller.gd`

- [ ] **Step 1: 增加自动移动相关变量**
- [ ] **Step 2: 实现路径跟随逻辑**
- [ ] **Step 3: 实现 WASD 无缝打断**

---

### Task 3: 水墨风全屏地图 UI (全屏独立场景)

**Files:**
- Create: `scripts/scenes/world_map_ui_screen.gd`

- [ ] **Step 1: 创建 UI 背景与画轴装饰**
- [ ] **Step 2: 实现水墨点击反馈**
- [ ] **Step 3: 坐标映射**

---

### Task 4: 整合与 [M] 键监听

**Files:**
- Modify: `scripts/scenes/map_screen_base.gd`
- Modify: `project.godot` (Input Map)

- [ ] **Step 1: 配置 Input Map**
- [ ] **Step 2: 实现场景切换逻辑**
