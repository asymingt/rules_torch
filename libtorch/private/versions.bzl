"""The PyTorch versions rules_torch can build.

Each entry pins the upstream source archive, names the overlay directory
(libtorch/overlay/<overlay>/) that adds the Bazel build to it, and lists the
patches applied to the upstream sources before the overlay is laid down. The
overlay follows upstream's tree layout, which rarely changes within a minor
release, so patch releases usually share one; patches are context diffs against
specific file revisions, so each version gets its own directory.
"""

LIBTORCH_VERSIONS = {
    "2.14.1": struct(
        urls = ["https://github.com/pytorch/pytorch/archive/refs/tags/v2.14.1.tar.gz"],
        integrity = "sha256-SzSGi6YcJHQN4nontsCcqggtpSGdZ1p96y27zhxas2Y=",
        strip_prefix = "pytorch-2.14.1",
        overlay = "2.14.1",
        patches = [
            "//libtorch/patches:2.14.1/glog_0_7_compat.patch",
            "//libtorch/patches:2.14.1/remove_placeholder_macros_h.patch",
        ],
        patch_strip = 1,
    ),
}

# The version used when no module asks for one.
DEFAULT_VERSION = "2.14.1"
