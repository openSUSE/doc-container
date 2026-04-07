# Doc CI

This is an example of a Docker container for a doc CI. At the moment, it is a functional toolchain providing environments for XML validation and rendering.

## Multi-Stage Toolchain

This project uses a multi-stage Docker build to provide two distinct images optimized for different CI workflows:

1. **Slim Image (`daps-slim`)** - Optimized for fast XML validation. It contains all direct dependencies of the `daps` package (without the building part).
2. **Full Image (`daps-full`)** - The complete environment for building PDFs and HTML, including Java (for `ditaa`) and a full set of CJK fonts.

## Building the Images

You can build specific stages of the toolchain using the `--target` flag:

### Build the Slim (Validation) Image

```bash
docker build --target daps-slim --build-arg RELEASE=16.0 -t daps16.0:slim .
```

### Build the Full (Building) Image

```bash
docker build --target daps-full --build-arg RELEASE=16.0 -t daps16.0:full .
```

## Naming Convention

When pushed to the registry, the images follow this naming convention:
- `latest` - The full toolchain image.
- `latest-slim` - The minimal validation image.
