# VyOS with dae/eBPF Kernel Support

This is a custom build of VyOS with additional kernel configurations to support [dae](https://github.com/daeuniverse/dae) transparent proxy.

## What's Different?

This build adds the following kernel configurations required by dae:

- ✅ `CONFIG_DEBUG_INFO_BTF=y` - BPF Type Format support
- ✅ `CONFIG_KPROBES=y` - Kernel probes
- ✅ `CONFIG_KPROBE_EVENTS=y` - Kprobe events
- ✅ `CONFIG_BPF_EVENTS=y` - BPF events

## Automated Builds

This repository uses GitHub Actions to automatically build VyOS ISOs on the 1st of each month.

Latest release: [Download here](https://github.com/MaurUppi/VyOS-current-eBPF/releases/latest)

## Quick Start

1. Download the latest ISO from [Releases](https://github.com/MaurUppi/VyOS-current-eBPF/releases)
2. Install VyOS as normal
3. Verify kernel support:
```bash
   # Check if BTF is available
   ls -la /sys/kernel/btf/vmlinux
   
   # Should output: -r--r--r-- 1 root root [size] ... /sys/kernel/btf/vmlinux
```
4. Configure dae container (see [Configuration Guide](#))

## Verification

Run the included verification script:
```bash
bash <(curl -s https://raw.githubusercontent.com/MaurUppi/VyOS-current-eBPF/master/scripts/verify-kernel.sh)
```

## Build Status

![Build Status](https://github.com/MaurUppi/VyOS-current-eBPF/actions/workflows/build-vyos.yml/badge.svg)

## Credits

- Kernel configs for [daeuniverse/dae](https://github.com/daeuniverse/dae)

## License

Same as VyOS - GPL v2

---

**Note**: This is an unofficial build. For official VyOS support, please visit [vyos.io](https://vyos.io).
