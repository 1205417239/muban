# DynamicXStandardAdjust

独立 Companion Tweak，目标为 DynamicX 1.4.7。

功能：
- 标准通知整体大小：60%~160%
- 白色通知：开/关
- 透明度：10%~100%，5%步进

默认：100% / 关闭 / 100%。

注意：这是第一版运行时 Hook 骨架。`layoutHostContainerViewDidLayoutSubviews:` 的实际 ABI 和 Host View 需要在目标设备上验证后，再锁定为正式版 Hook。
