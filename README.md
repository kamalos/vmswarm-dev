# VMSwarm

VMSwarm is a bash-first CLI tool to spin up, manage, and orchestrate multiple KVM virtual machines using libvirt/virsh. It supports parallel execution via subshell, fork (C), or threads (C).

## Features

- **KVM/libvirt Orchestration:** Effortlessly spin up and manage virtual machines.
- **Parallel Execution:** Fast execution across multiple VMs using Bash subshells, C-based process forks, or C-based POSIX threads.
- **Modular Architecture:** Clean, file-separated codebase for easy maintenance and extensibility.
- **Complete Lifecycle Management:** Create, start, stop, kill, pause, resume, suspend, and delete VMs.
- **Advanced Operations:** Support for SSH execution, cloning, tagging, networking, snapshots, and full VM import/export.

## Prerequisites

- Bash environment
- KVM & libvirt installed (`libvirtd` running)
- `virsh` CLI tool
- GCC and Make (for compiling C extensions)

**Optional but recommended:**
- `virt-manager` (for a graphical interface to view and manage VMs alongside VMSwarm)
- `qemu-utils` (for advanced qcow2 image manipulation)

## Installation

Clone the repository and install it directly using `make`. The `install` target will automatically compile the C binaries and install the application along with its manual page.

```bash
git clone https://github.com/kamalos/vmswarm-dev.git
cd vmswarm-v1

# Compile and install VMSwarm to system directories (requires root)
sudo make install
```

To remove VMSwarm from your system:

```bash
sudo make uninstall
```

## Usage

```bash
vmswarm [OPTIONS] COMMAND [TARGET] [ARGS]
```

### Execution Options

- `-f` : Fork-based parallel execution (C binary)
- `-t` : Thread-based parallel execution (C binary)
- `-s` : Subshell execution (Bash)
- `-n <count>` : Number of VMs for batch creation
- `-l <dir>` : Set log directory (default: `/var/log/vmswarm`)
- `-v` : Verbose output
- `-r` : Restore config defaults (root only)
- `-h` : Show short help message

### Commands

| Command | Description |
|---|---|
| `create` | Provision a new KVM VM (from ISO or qcow2). Prompts for missing parameters. |
| `start` | Start VM(s). |
| `stop` | Graceful shutdown of VM(s). |
| `kill` | Force-off VM(s). |
| `pause` | Suspend VM(s) in memory. |
| `resume` | Resume paused VM(s). |
| `suspend` | Save VM state to disk. |
| `delete` | Undefine and remove VM(s) [requires root]. |
| `ps` | List VMs with state, RAM, CPUs, tags, IP. |
| `info` | Detailed info for VM(s). |
| `ssh` | SSH into VM(s). |
| `run` | Execute a local script on VM(s) via SSH. |
| `clone` | Clone an existing VM. |
| `tag` | Add/remove/list tags. |
| `snap` | Manage snapshots (take/list/restore/delete). |
| `net` | Manage libvirt networks (list/create/delete). |
| `export` | Export VM to portable archive. |
| `import` | Import VM from archive. |
| `logs` | Read and filter the vmswarm log file. |

### Target Syntax

You can apply commands to one or multiple VMs using various targeting syntaxes:

- **By VM name:** `worker-1`
- **By numeric ID:** `3`
- **ID range:** `1-5`
- **Explicit IDs:** `id:1,3,7`
- **By tag:** `tag:cluster`
- **All registered VMs:** `all`

## Examples

**Batch Creation**
Create 3 VMs based on a qcow2 image, tagging them as part of a cluster:
```bash
vmswarm -s -n 3 create --name node --tag cluster --import base.qcow2
```

**List VMs by Tag**
```bash
vmswarm ps --tag cluster
```

**Parallel Execution (Fork)**
Run a deployment script on all VMs with the 'cluster' tag simultaneously using C fork execution:
```bash
vmswarm -f run tag:cluster --script deploy.sh
```

**Parallel Execution (Threads)**
Start VMs 1 through 10 using C thread-based parallel execution:
```bash
vmswarm -t start 1-10
```

**Snapshots**
Take a snapshot of all registered VMs:
```bash
vmswarm snap take all --name pre-update
```

**Export**
Export a specific VM for backup:
```bash
vmswarm export worker-1 --out /backups
```

**Logs**
Read the last 50 lines of logs, filtering for errors:
```bash
vmswarm logs --tail 50 --grep ERROR
```

## Documentation

Full manual is available via the `man` page after installation, or by reading the `vmswarm.1` file directly.
