# Reassembling the localrepo package

The bundled repository carries the ML models, which puts it over GitHub's
2 GiB release-asset limit, so it is also published as split parts.

Download every `*.part-NN` file, then:

```bash
cat autoware-localrepo-1-9-0_*.part-* > autoware-localrepo-1-9-0.deb
sha256sum -c SHA256SUMS.txt --ignore-missing
sudo dpkg -i autoware-localrepo-1-9-0.deb
```

If you are fetching from a host without the 2 GiB limit, download the single
`.deb` directly and skip the `cat` step.
