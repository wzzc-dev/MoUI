# Plan: Linux RISC-V64 support

- **Status**: active
- **Goal**: Add an experimental `riscv64-linux-gnu` build and real-Skia L0-L2
  evidence path by reusing the canonical Linux Skia route.
- **Non-goals**: No new platform backend or Showcase route, no Vulkan/WGPU
  support, and no matching-device Linux Wayland L3 claim.

## Acceptance

- [x] Ubuntu 24.04.4 RISC-V64 sysroot and Zig 0.16.0 are locked by SHA-256.
- [ ] Existing Linux Skia Showcase cross-build emits an ELF64 RISC-V binary.
- [ ] QEMU executes the offscreen Skia renderer and text/emoji smokes with
      raster-only linking and no Vulkan dependency.
- [x] Platform metadata records the architecture variant without changing the
      14 canonical routes.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-10 | Use `riscv64-linux-gnu` glibc, Ubuntu 24.04.4 sysroot, Zig 0.16.0, and Skia Raster first. |

## Progress

| Date | Note |
|------|------|
| 2026-08-10 | Plan approved; implementation in progress. |
| 2026-08-10 | Metadata/schema tests, locked sysroot preparation, Release cross-build helper, scheduled/manual CI, and bilingual guidance implemented. Local validators and helper negative tests pass; real Linux RISC-V64 L0/L2 evidence remains pending the scheduled/manual Linux workflow. |
