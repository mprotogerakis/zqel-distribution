# zqel-distribution

The **released binary packages** of zqel — and nothing else.

zqel is built in a separate, non-public tree. Only what has passed every gate
lands here. The source is deliberately not included: a package carries a
binary and the contracts you compile against.

## What is here

| Release | Meaning |
|---|---|
| `nightly` | A moving pointer at the last **green** build. Its assets are replaced on every run. |
| `v…` | Tagged versions. Immutable — an asset that is there is never overwritten. |

Every archive has a `.sha256` beside it:

```sh
base=https://github.com/mprotogerakis/zqel-distribution/releases/download/nightly
curl -fLO $base/zqel-nightly-linux-x86_64.tar.gz
curl -fLO $base/zqel-nightly-linux-x86_64.tar.gz.sha256
sha256sum -c zqel-nightly-linux-x86_64.tar.gz.sha256
```

## What a package says about itself

```sh
tar xzf zqel-nightly-linux-x86_64.tar.gz
./zqel/zqel --version
./zqel/zqel toolchain --json
```

`toolchain --json` reports the prover this package computes with, and whether
it is the pinned one. A version number alone does not tell you that: two
builds carrying the same number can have been computed with different provers.

## Why the prover identity matters

zqel's verdicts are produced by Z3. A verdict is only as meaningful as the
prover that produced it, so this project pins Z3 **by artifact hash, not by
version number** — `z3-pin.json`, shipped inside every package, records the
SHA-256 of the exact `libz3` that was used. The binary checks the loaded
library against that hash on every start and refuses to run if it differs.
In a released package this check cannot be switched off.

You do not have to take our word for the check. On Linux you can compute it
yourself:

```sh
# The value the package claims, and the library it actually ships:
python3 -c "import json;print(json.load(open('zqel/z3-pin.json'))['artifacts']\
['z3_solver-5.1.0.0-py3-none-manylinux_2_27_x86_64.whl']['lib_sha256'])"
sha256sum zqel/z3/lib/libz3.so
```

Both numbers must be the same, and both must match the `libz3` inside the
published wheel named in `z3-pin.json`.

## On macOS the hashes will NOT match — and that is expected

macOS packages are code-signed with a Developer ID and notarized by Apple.
Without that, Gatekeeper refuses to run them. Apple inspects **every** Mach-O
object inside the archive, so `libz3` has to be signed too — and signing
rewrites the file. Its SHA-256 therefore no longer equals the hash recorded in
the pin.

The obvious reply — "just strip the signature and hash it again" — does not
work: `codesign --remove-signature` also removes the original linker
signature, and a re-applied one comes out different. All three routes were
measured.

What *does* work is that signing only touches what the signature describes.
Measured on a real pair of files:

    8 differing bytes out of 27,369,664 before the signature (99.999971 %)
    all eight inside two load commands:
      LC_SEGMENT_64 __LINKEDIT   the segment size
      LC_CODE_SIGNATURE          the size of the signature

Code, data and symbols are untouched. `derselbe_beweiser.sh` (German for
"the same prover") checks exactly that: everything **after** the load commands
and **before** the signature must be byte-identical.

```sh
# 1. the shipped, signed library
tar xzf zqel-nightly-macos-arm64.tar.gz

# 2. the library from the wheel the pin names
rel=$(python3 -c "import json;print(json.load(open('zqel/z3-pin.json'))['archived_release'])")
whl=z3_solver-5.1.0.0-py3-none-macosx_13_3_arm64.whl
curl -fLO https://dl.zqel.org/zqel/z3/$rel/$whl
unzip -q $whl -d wheel

# 3. compare
sh derselbe_beweiser.sh zqel/z3/lib/libz3.dylib wheel/z3/lib/libz3.dylib
```

It is a POSIX shell script on purpose: checking this should require installing
nothing and trusting nothing. `otool`, `dd` and `shasum` are on every Mac.

> **Note on the wheel address.** The `url` and `mirror` fields inside
> `z3-pin.json` currently point at hosts you cannot reach from outside. The
> address shown above is the one that works today, and it is being moved into
> this repository. Until that is done, verification of the prover identity
> depends on a host that is scheduled to go away.

## Licences

Every package contains `NOTICE.txt` and a `licenses/` directory listing the
embedded components and their licence texts. Read those rather than this file;
they are generated from the build, not maintained by hand.

## Reporting a problem

The source tree is not public, so there is no issue tracker here. If something
in a package is wrong, the `.sha256`, the output of `toolchain --json` and the
`quelle_commit` from `DISTRIBUTION.txt` are what identify the build.
