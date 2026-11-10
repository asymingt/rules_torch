"""Repository rule that materializes @libtorch.

Fetches a PyTorch source archive, applies patches to it, and copies an overlay
directory (the Bazel build: BUILD files, .bzl files and helper sources) on top,
the same way a registry overlay is laid over a module's archive. Within the
overlay directory BUILD files are stored as `BUILD.torch`, so that they are not
packages of rules_torch itself; they are renamed to `BUILD.bazel` on the way in.
"""

def _copy_overlay_tree(rctx, src_dir):
    # Starlark has no recursion: an explicit stack of (directory, prefix).
    pending = [(src_dir, "")]
    for _ in range(100000):
        if not pending:
            break
        directory, prefix = pending.pop()
        for entry in directory.readdir():
            name = entry.basename
            if entry.is_dir:
                pending.append((entry, prefix + name + "/"))
                continue
            if name == "BUILD.torch":
                name = "BUILD.bazel"
            rctx.file(
                prefix + name,
                rctx.read(entry),
                executable = False,
                legacy_utf8 = False,
            )

def _libtorch_repository_impl(rctx):
    rctx.download_and_extract(
        url = rctx.attr.urls,
        integrity = rctx.attr.integrity,
        sha256 = rctx.attr.sha256,
        stripPrefix = rctx.attr.strip_prefix,
        type = rctx.attr.type,
    )
    for patch in rctx.attr.patches:
        rctx.patch(patch, strip = rctx.attr.patch_strip)

    overlay_dir = rctx.path(rctx.attr.overlay).dirname
    rctx.watch_tree(overlay_dir)
    _copy_overlay_tree(rctx, overlay_dir)

libtorch_repository = repository_rule(
    implementation = _libtorch_repository_impl,
    doc = "A PyTorch source tree with rules_torch's Bazel build laid over it.",
    attrs = {
        "urls": attr.string_list(
            mandatory = True,
            doc = "URLs of the PyTorch source archive.",
        ),
        "integrity": attr.string(
            doc = "Subresource Integrity checksum of the archive.",
        ),
        "sha256": attr.string(
            doc = "SHA-256 of the archive, if `integrity` is not given.",
        ),
        "strip_prefix": attr.string(
            doc = "Directory prefix to strip from the archive.",
        ),
        "type": attr.string(
            doc = "Archive type (e.g. \"tar.gz\"), if the URLs do not end in a known suffix.",
        ),
        "patches": attr.label_list(
            doc = "Patches applied to the upstream sources, in order, before the overlay.",
        ),
        "patch_strip": attr.int(
            default = 1,
            doc = "Number of leading path components stripped from the patches (`patch -p`).",
        ),
        "overlay": attr.label(
            mandatory = True,
            allow_single_file = True,
            doc = "The root `BUILD.torch` of the overlay directory to copy into the repository.",
        ),
    },
)
