"""The `libtorch` module extension: chooses a PyTorch source and builds @libtorch.

    libtorch = use_extension("@rules_torch//libtorch:extensions.bzl", "libtorch")
    libtorch.version(version = "2.14.1")
    use_repo(libtorch, "libtorch")

`version` picks one of the releases rules_torch knows how to build (see
private/versions.bzl). `source` builds a custom archive (a fork, a commit)
with the overlay and, by default, the patches of one of those versions:

    libtorch.source(
        version = "2.14.1",
        urls = ["https://github.com/pytorch/pytorch/archive/<sha>.tar.gz"],
        strip_prefix = "pytorch-<sha>",
        integrity = "sha256-...",
    )

The root module decides. Non-root modules may ask for a `version` (they must all
agree); their `source` tags are ignored. With no tags at all, the newest known
version is built.
"""

load("//libtorch/private:repo.bzl", "libtorch_repository")
load("//libtorch/private:versions.bzl", "DEFAULT_VERSION", "LIBTORCH_VERSIONS")

def _known(version):
    if version not in LIBTORCH_VERSIONS:
        fail("rules_torch does not know PyTorch {}; supported versions: {}".format(
            version,
            ", ".join(sorted(LIBTORCH_VERSIONS.keys())),
        ))
    return LIBTORCH_VERSIONS[version]

def _overlay_label(release):
    return Label("//libtorch/overlay:{}/BUILD.torch".format(release.overlay))

def _libtorch_impl(mctx):
    root_version = None
    root_source = None
    requested = {}  # version -> [module names]

    for mod in mctx.modules:
        if mod.is_root:
            tags = len(mod.tags.version) + len(mod.tags.source)
            if tags > 1:
                fail("the root module may have at most one libtorch.version() or libtorch.source() tag, found {}".format(tags))
            if mod.tags.version:
                root_version = mod.tags.version[0].version
            elif mod.tags.source:
                root_source = mod.tags.source[0]
        else:
            for tag in mod.tags.source:
                # buildifier: disable=print
                print("rules_torch: libtorch.source() in non-root module '{}' is ignored; only the root module may choose a custom PyTorch source".format(mod.name))
            for tag in mod.tags.version:
                requested.setdefault(tag.version, []).append(mod.name)

    if root_source != None:
        release = _known(root_source.version)
        patches = []
        if root_source.default_patches:
            patches += [Label(p) for p in release.patches]
        patches += root_source.patches
        libtorch_repository(
            name = "libtorch",
            urls = root_source.urls,
            integrity = root_source.integrity,
            sha256 = root_source.sha256,
            strip_prefix = root_source.strip_prefix,
            type = root_source.type,
            patches = patches,
            patch_strip = root_source.patch_strip,
            overlay = _overlay_label(release),
        )
    else:
        if root_version != None:
            version = root_version
        elif len(requested) > 1:
            fail("modules ask for different PyTorch versions and the root module does not choose one: {}".format(
                "; ".join(["{} by {}".format(v, ", ".join(m)) for v, m in requested.items()]),
            ))
        elif requested:
            version = requested.keys()[0]
        else:
            version = DEFAULT_VERSION
        release = _known(version)
        libtorch_repository(
            name = "libtorch",
            urls = release.urls,
            integrity = release.integrity,
            strip_prefix = release.strip_prefix,
            patches = [Label(p) for p in release.patches],
            patch_strip = release.patch_strip,
            overlay = _overlay_label(release),
        )

    return mctx.extension_metadata(
        reproducible = True,
        root_module_direct_deps = "all",
        root_module_direct_dev_deps = [],
    )

_version_tag = tag_class(
    doc = "Build one of the PyTorch versions rules_torch knows.",
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "A PyTorch version, e.g. \"2.14.1\".",
        ),
    },
)

_source_tag = tag_class(
    doc = "Build a custom PyTorch source archive. Root module only.",
    attrs = {
        "version": attr.string(
            mandatory = True,
            doc = "The known PyTorch version whose overlay (and, by default, patches) to use.",
        ),
        "urls": attr.string_list(
            mandatory = True,
            doc = "URLs of the source archive.",
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
        "default_patches": attr.bool(
            default = True,
            doc = "Also apply rules_torch's patches for `version`, before `patches`.",
        ),
        "patches": attr.label_list(
            doc = "Additional patches to apply to the upstream sources.",
        ),
        "patch_strip": attr.int(
            default = 1,
            doc = "Number of leading path components stripped from the patches (`patch -p`). rules_torch's own patches are -p1.",
        ),
    },
)

libtorch = module_extension(
    implementation = _libtorch_impl,
    doc = "Downloads a PyTorch source release and creates @libtorch from it.",
    tag_classes = {
        "version": _version_tag,
        "source": _source_tag,
    },
)
