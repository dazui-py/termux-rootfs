# termux-rootfs

Clean Termux rootfs builder for `termux-sandbox`.

This repository does not store rootfs binaries in git. It provides scripts to fetch the official Termux bootstrap archive, extract it into a Termux-compatible filesystem layout, restore bootstrap symlinks, and package the result as a reusable rootfs archive.

## Why

`termux-sandbox` needs a clean Termux-like rootfs for each sandbox.

Inside a sandbox, programs should see:

```text
/data/data/com.termux/files/home
/data/data/com.termux/files/usr
