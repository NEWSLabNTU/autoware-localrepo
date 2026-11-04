The ML models for Autoware 1.9.0, packaged as Debian packages for machines
that cannot download them. **You do not need these to install Autoware.**

Autoware itself comes from the localrepo release, e.g.
[Autoware 1.9.0-1](https://github.com/NEWSLabNTU/autoware-localrepo/releases/tag/1.9.0-1),
and on a machine with internet access its `autoware-download-models-1-9-0`
fetches the same models from their upstream servers. Use these debs only when
the machine cannot reach those servers (`awf.ml.dev.web.auto`, Hugging Face,
S3). They are architecture-independent: the same files serve x86_64, arm64
servers and Jetson.

## Download

| File | Contents |
|------|----------|
| `autoware-data-1-9-0_1.9.0-1_all.deb` | depends on the three below |
| `autoware-data-perception3d-1-9-0_1.9.0-1_all.deb` | 3D perception models, 1.06 GB |
| `autoware-data-planning-1-9-0_1.9.0-1_all.deb` | planning models, 553 MB |
| `autoware-data-vision-1-9-0_1.9.0-1_all.deb` | camera and traffic light models, 830 MB |
| `SHA256SUMS.txt` | checksums |

Each asset stays under GitHub's 2 GiB limit.

## Install

Install Autoware 1.9.0 from its localrepo release first. Then, on the target
machine:

```bash
# (Optional) verify the download
sha256sum --ignore-missing -c SHA256SUMS.txt

# Install the models under /opt/autoware/1.9.0/data
sudo dpkg -i autoware-data-*1-9-0_1.9.0-1_all.deb

# As the user who launches Autoware, not with sudo:
# link them into ~/autoware_data, then check them
autoware-download-models-1-9-0 --link-from /opt/autoware/1.9.0/data
autoware-download-models-1-9-0 --verify
```

The files stay in the root-owned `/opt/autoware/1.9.0/data`. `~/autoware_data`
(Autoware's default `data_path`) gets directories of your own with symlinks to
them, so TensorRT can still write the `.engine` files it compiles on first
launch. `--only` and `--group` select a subset, as when downloading.

## Removal

```bash
sudo apt remove autoware-data-1-9-0 autoware-data-perception3d-1-9-0 autoware-data-planning-1-9-0 autoware-data-vision-1-9-0
rm -rf ~/autoware_data      # the links and the TensorRT engines, per user
```

`/usr/share/autoware/1.9.0/uninstall-autoware.sh` removes these packages too,
together with the rest of Autoware 1.9.0.
