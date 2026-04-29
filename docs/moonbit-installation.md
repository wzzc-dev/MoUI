# MoonBit 安装指南

## 官方安装方法

### 方法一：自动安装脚本（推荐）

```bash
# Linux / macOS
curl -fsSL https://get.moonbitlang.com/ | bash

# 或
curl -fsSL https://moonbitlang.github.io/install/moon-install.sh | bash
```

### 方法二：手动下载

1. 访问 [MoonBit GitHub Releases](https://github.com/moonbitlang/moonbit/releases)
2. 下载对应平台的二进制包
3. 解压并将 `moon` 可执行文件添加到 PATH

### 方法三：使用 Cargo 安装

```bash
cargo install moonbitc
```

## 验证安装

```bash
moon version
```

输出示例：
```
MoonBit version 0.1.0 (abc1234)
```

## 环境变量配置

安装后，需要将 MoonBit 加入环境变量：

```bash
# Linux / macOS - 添加到 ~/.bashrc 或 ~/.zshrc
export PATH="$HOME/.moon/bin:$PATH"
```

## 当前环境状态

**⚠️ 注意**：当前开发环境由于网络限制，无法直接下载和安装 MoonBit 编译器。

### 替代方案

虽然无法直接安装，但项目已包含预编译的示例插件：

1. **计数器插件**：`plugins/counter/counter.component.wasm`
2. **Todo 插件**：已创建完整的源代码，但需要 MoonBit 编译

### 在其他环境中安装

如果你在本地环境操作，可以按照以下步骤安装：

```bash
# 1. 安装 MoonBit
curl -fsSL https://get.moonbitlang.com/ | bash

# 2. 配置环境变量
source ~/.bashrc

# 3. 验证安装
moon version

# 4. 编译 Todo 插件
cd plugins/todo
moon build --target wasm

# 5. 创建 WASM 组件
wasm-tools component embed wit/ target/wasm/release/build/gen/gen.wasm \
    --encoding utf16 -o todo.wasm
wasm-tools component new todo.wasm -o todo.component.wasm

# 6. 运行
cargo run --bin moui -- plugins/todo/todo.component.wasm
```

## 依赖工具

### wasm-tools

```bash
cargo install wasm-tools
```

### wit-bindgen

```bash
cargo install wit-bindgen-cli
```

## 常见问题

### 网络连接失败

如果遇到 SSL 或网络连接问题，可以尝试：

```bash
# 设置代理（如果需要）
export https_proxy=http://proxy:port

# 或使用 HTTP
curl -fsSL http://get.moonbitlang.com/ | bash
```

### 权限问题

```bash
# 确保目录可写
chmod -R 755 ~/.moon
```

### 版本不兼容

```bash
# 更新到最新版本
moon update
```

## 资源链接

- [MoonBit 官方网站](https://moonbitlang.github.io/)
- [MoonBit GitHub](https://github.com/moonbitlang/moonbit)
- [MoonBit 文档](https://moonbitlang.github.io/moonbit-book/)
