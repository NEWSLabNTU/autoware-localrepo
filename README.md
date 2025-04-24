# Autoware Local Repository Builder

The project is used to create a local repository for Autoware for
Debian/Ubuntu systems. Users can download the local repository and
install all needed Autoware binaries and configuration files.

## Prerequisites

- **Ubuntu 22.04** operating system is recommended.
- [makedeb](https://www.makedeb.org/) packaging tool.
- GNU Parallel. It can be obtained by the command `sudo apt install
  parallel`.

## Usage

Create a `packages` directory containing all Autoware packages to be
packed into the local repository.

```
> ls packages
ros-humble-ad-api-adaptors_0.40.0-0jammy_amd64.deb
ros-humble-ad-api-adaptors-dbgsym_0.40.0-0jammy_amd64.ddeb
ros-humble-ad-api-visualizers_0.40.0-0jammy_amd64.deb
...
```

Run this command to build the local repository. The
`autoware-localrepo_*.deb` will be created in the output directory.

```sh
mkdir output
./build.sh ./packages ./output
```
