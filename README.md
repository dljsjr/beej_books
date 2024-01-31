# beej_books

Submodule References to all of Beej's Guides (that are on GitHub) with a portable POSIX script
that builds the `epub` target for all of them at once.

## Setup/Build Instructions

You'll need to install the prereqs outlined by Beej in the various READMEs of the subrepos.

I make no promise that the following deps snippet is up to date, but it's what's in said READMEs at the
time of this writing. Refer to the submodule READMEs for the most up to date dependencies:

### Dependencies

* [Gnu make](https://www.gnu.org/software/make/) (XCode make works, too)
* [Python 3+](https://www.python.org/)
* [Pandoc 2.7.3+](https://pandoc.org/)
* XeLaTeX (can be found in [TeX Live](https://www.tug.org/texlive/))
* [Liberation fonts](https://en.wikipedia.org/wiki/Liberation_fonts) (sans, serif, mono)

Mac dependencies install (reopen terminal after doing this):

```bash
xcode-select --install                  # installs make
brew install python                     # installs Python3
brew install pandoc
brew install mactex                     # installs XeLaTeX
brew tap homebrew/cask-fonts
brew install font-liberation            # installs Liberation fonts
```

## Usage

1. `git submodule update --init --recursive` (or just initialize the books you want to build).
2. `./make_epubs.sh`

Epub files will be placed in a `./epubs` directory.
