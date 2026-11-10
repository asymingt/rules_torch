# rules_torch

Bazel rules that build [LibTorch](https://pytorch.org/cppdocs/) — the C++
library of PyTorch — **from source**, with a hermetic LLVM toolchain and
multi-vendor GPU support (NVIDIA CUDA, AMD ROCm/HIP, Intel XPU, Vulkan and
Apple MPS), cross-compilable between Linux, macOS and Windows on `x86_64` and
`arm64`.

`rules_torch` contains no PyTorch code. Its `libtorch` module extension
downloads a PyTorch source release of your choice and lays a Bazel build over
it, producing the `@libtorch` repository (`@libtorch//:torch`,
`@libtorch//:c10`, `@libtorch//:torch_cuda`, ...). The rationale, the target
and platform matrix, and the CI that builds all of it live in
[bazel_libtorch](https://github.com/asymingt/bazel_libtorch).

## Usage

Bazel 9.0 or newer. Point `.bazelrc` at the
[bazel_libtorch registry](https://asymingt.github.io/bazel_libtorch/), which
serves `rules_torch` and the companion modules of `@libtorch` that are not yet
in the Bazel Central Registry, ahead of the BCR:

```
common --registry=https://asymingt.github.io/bazel_libtorch/
common --registry=https://bcr.bazel.build
```

Then, in `MODULE.bazel`:

```starlark
bazel_dep(name = "llvm", version = "0.8.25")      # hermetic Clang/libc++ toolchain
bazel_dep(name = "rules_cuda", version = "0.3.0") # CUDA rules & redistributables
bazel_dep(name = "rules_torch", version = "0.0.1")
register_toolchains("@llvm//toolchain:all")

libtorch = use_extension("@rules_torch//libtorch:extensions.bzl", "libtorch")
libtorch.version(version = "2.14.1")
use_repo(libtorch, "libtorch")
```

```starlark
load("@rules_cc//cc:defs.bzl", "cc_binary")

cc_binary(
    name = "app",
    srcs = ["main.cc"],
    deps = ["@libtorch//:torch"],
)
```

```
bazel build //:app
bazel build //:app --platforms=@llvm//platforms:macos_arm64     # cross-compile
bazel build //:app --@libtorch//:gpu=rocm                        # AMD instead of NVIDIA
```

The overlays assume Clang with `libc++` (MinGW-UCRT on Windows) and
`-std=gnu++20`; see bazel_libtorch's README for the `.bazelrc` flags its CI
uses, the targets per platform, and the accelerator flags
(`--@libtorch//:gpu`, `--@libtorch//:enable_<backend>`,
`--@libtorch//:rocm_archs`).

## Choosing the PyTorch source

Every PyTorch version `rules_torch` supports is an entry in
[`libtorch/private/versions.bzl`](libtorch/private/versions.bzl): a pinned
source archive, an overlay directory
([`libtorch/overlay/<version>/`](libtorch/overlay)) holding the Bazel build
(`BUILD` files, stored as `BUILD.torch`, and `.bzl` files), and the patches
([`libtorch/patches/<version>/`](libtorch/patches)) applied to the upstream
sources first.

| Tag | What it does |
| --- | --- |
| `libtorch.version(version = "2.14.1")` | Build a supported release: its archive, patches and overlay. |
| `libtorch.source(version = "2.14.1", urls = [...], integrity = "...", strip_prefix = "...", patches = [...], default_patches = True, type = "tar.gz")` | Build an archive of your own — a fork, a commit — with the overlay and (by default) the patches of a supported version. Root module only. |
| *(no tag)* | The newest supported version. |

The root module decides; if it has no tag, non-root modules may ask for a
`version` as long as they all agree. Conflicts and unknown versions fail with a
message listing what is supported.

The overlay tracks upstream's tree layout, so an archive close to the named
version — a patch release, a fork of it — builds as is, while a different minor
release needs an overlay of its own, i.e. a new `rules_torch` release. Fixing a
patch for an already supported PyTorch version is likewise a `rules_torch`
release, which is why its version is independent of PyTorch's.

## How @libtorch is assembled

`libtorch/private/repo.bzl` is a repository rule that, in order:

1. downloads and extracts the archive;
2. applies the patches (`patch -p1`);
3. copies the overlay directory into the repository, renaming `BUILD.torch` to
   `BUILD.bazel`; overlay files win over upstream files.

Everything the overlay's BUILD files refer to (`@fbgemm`, `@sleef`, `@cuda`,
`@llvm//tools:...`, the hermetic Python used by `torchgen`, ...) is a
dependency of `rules_torch` itself, so consumers only declare `rules_torch`.

## History

`@libtorch` was first published as a module of its own
(`bazel_dep(name = "libtorch", version = "2.14.1")`, with the Bazel build as a
registry overlay), which the
[ROS Central Registry](https://github.com/openrobotics/ros-central-registry)
carries. That module is deprecated: swap the `bazel_dep` for the three lines
above; `@libtorch//...` targets and `--@libtorch//:...` flags are unchanged.
