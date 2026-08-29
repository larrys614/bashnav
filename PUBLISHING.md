# Publishing this to GitHub

Everything here is ready to push. What it needs from you is a GitHub account and
about ten minutes. Run **one block at a time** and check the output before moving
on. Blocks are marked *(read-only)* or *(changes things)*.

> **The repository does not exist until you do step 3.** Until then,
> `github.com/larrys614/bashnav` is a 404 — which is what the link from
> `colregs review` will land on, and what any link in the README points at. That
> is expected, not a fault: nothing is lost, and a review already written is
> saved as a file on the reviewer's own machine to send once the repo is up.

## 1. Your username — (read-only)

Already filled in throughout as **`larrys614`**. Nothing to do unless you want a
different account, in which case set it here and run step 2:

```sh
GH_USER=larrys614
```

## 2. Put your username into the files — (changes things)

Two files carry a placeholder: the README's clone command and the site's links.

```sh
X && rm -f README.md.bak
GH_USER="$GH_USER" ./docs/make-site.sh
```

*(On macOS `sed -i.bak` is correct as written; the `.bak` file is removed for you.)*

## 3. Check it still builds and passes — (read-only)

```sh
./build.sh && ./tests/run-tests.sh && ./tests/golden.sh
```

You want `ALL TESTS PASSED` and `GOLDEN: no output changed`. If your machine has
`dash`, `mawk` and `gawk`, run the full matrix instead:

```sh
SHELLS="dash bash" AWKS="mawk gawk" ./tests/run-tests.sh
```

## 4. Make it a git repository — (changes things)

If you have never used git on this machine, set your name and email first;
they go into every commit.

```sh
git config --global user.name "Larry Sherman"
git config --global user.email "m.larry.sherman@gmail.com"
```

Then:

```sh
git init
git add .
git commit -m "Bash Navigation Software: celnav 1.5 and colregs 1.15"
git branch -M main
```

## 5. Create the repository on GitHub — (changes things)

**The simple way, in a browser.** Go to **github.com/new**. Repository name
`bashnav`, description *Marine navigation tools in POSIX shell and awk*, set it
**Public**, and **add nothing**: leave "Add a README", "Add .gitignore" and
"Choose a license" all untouched. You already have all three, and if GitHub
creates its own the push in step 6 is rejected with `Updates were rejected
because the remote contains work that you do not have locally` — which is the
single most common way a first push goes wrong. An empty repository is what you
want; GitHub will show you a page of setup commands, which you can ignore
because step 6 is the same thing.

**Or, if you have the `gh` command installed and signed in:**

```sh
gh repo create bashnav --public --source=. --description "Marine navigation tools in POSIX shell and awk"
```

If you used `gh`, skip to step 7.

## 6. Push it — (changes things)

```sh
git remote add origin https://github.com/$GH_USER/bashnav.git
git push -u origin main
```

GitHub will ask you to authenticate. It will not take your account password:
use a **personal access token** as the password. Create one at
**github.com/settings/tokens** → Generate new token (classic) → tick `repo` →
generate, then copy it. Paste it when git asks for a password. Save it in your
password manager; GitHub shows it once.

## 7. Turn on the website — (changes things)

In the repository: **Settings → Pages**. Under "Build and deployment", set
Source to **Deploy from a branch**, Branch to **main**, folder to **/docs**, and
Save.

A minute or two later the site is live at:

```
https://YOUR-USERNAME.github.io/bashnav/
```

Put that URL into the repository's "About" panel (the gear icon top right of the
repository home page) along with a few topics: `navigation`, `celestial-navigation`,
`colregs`, `sailing`, `posix`, `shell`, `awk`.

## 8. Offer the two files as a release — (changes things, optional)

People who only want the tools should not have to clone anything.

```sh
git tag -a v1.1 -m "celnav 1.1, colregs 1.0"
git push origin v1.1
```

Then on GitHub: **Releases → Draft a new release**, choose tag `v1.1`, and drag
`bin/celnav` and `bin/colregs` into the binaries box. Now anyone can download a
single working file straight from the release page.

---

## Afterwards

**Changing anything.** Edit files in `src/`, never in `bin/`. Then:

```sh
./build.sh && ./tests/run-tests.sh && ./docs/make-site.sh
```

CI runs the same three things on every push and will tell you if `bin/` was left
out of date.

**The site rebuilds from real output.** `docs/make-site.sh` runs the tools and
drops their actual output into the page, so the screenshots on the site can never
drift away from what the programs do.

**Issues and pull requests.** `CONTRIBUTING.md` sets out what you will want from
contributors: POSIX shell and awk only, no dependencies, edit `src/` not `bin/`,
add a test. It also tells people how to report an error in the COLREGs content —
which is the class of bug most worth catching.

## After the first push — check the review link works

`colregs review` builds a link to an issue on the repository you have just
created. Until the repository exists that link is a 404; once it exists, walk it
once yourself end to end:

```sh
./bin/colregs review     # 2, flag one thing, q, then 9
```

Open the link it prints. GitHub should show a **new issue form, already filled
in**, with a title like `colregs review: 1 flagged` and your note in the body.
Do not submit it — just check it arrives complete, then close the tab.

Two things to know about that link:

- It carries no `labels=` parameter on purpose, so it does not depend on a label
  existing in the repository. Label review issues yourself once they arrive.
- A very long review will not fit in a URL. The tool detects that, writes the
  report to `~/.colregs/review-report.md` instead, and tells the reviewer to
  attach it to a new issue. Worth testing that path too if you want to be
  thorough: answer thirty or forty claims with notes and try to submit.
